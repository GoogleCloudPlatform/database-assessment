# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Health checker for SQL Server deployment."""

from __future__ import annotations

import subprocess  # noqa: S404
from dataclasses import dataclass
from datetime import UTC, datetime
from enum import Enum
from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from tools.lib.container import ContainerRuntime


class HealthStatus(str, Enum):
    """Health status levels."""

    HEALTHY = "healthy"
    DEGRADED = "degraded"
    UNHEALTHY = "unhealthy"
    UNKNOWN = "unknown"
    NOT_APPLICABLE = "not_applicable"


@dataclass
class ComponentHealth:
    """Health status for a component."""

    name: str
    status: HealthStatus
    message: str
    details: dict[str, Any] | None = None
    suggestions: list[str] | None = None


@dataclass
class SystemHealth:
    """Overall system health."""

    overall_status: HealthStatus
    components: list[ComponentHealth]
    timestamp: str

    @property
    def is_healthy(self) -> bool:
        """Check if system is fully healthy."""
        return self.overall_status == HealthStatus.HEALTHY

    @property
    def healthy_components(self) -> list[ComponentHealth]:
        """Get list of healthy components."""
        return [c for c in self.components if c.status == HealthStatus.HEALTHY]

    @property
    def unhealthy_components(self) -> list[ComponentHealth]:
        """Get list of unhealthy components."""
        return [c for c in self.components if c.status in {HealthStatus.UNHEALTHY, HealthStatus.DEGRADED}]


class HealthChecker:
    """Check health of SQL Server deployment components."""

    def __init__(self, console: Console | None = None) -> None:
        """Initialize health checker.

        Args:
            console: Rich console for output (creates new if None)
        """
        self.console = console or Console()
        self.runtime = ContainerRuntime()

    def check_all(self, *, verbose: bool = False) -> SystemHealth:
        """Check health of all components.

        Args:
            verbose: Include detailed diagnostic information

        Returns:
            SystemHealth: Comprehensive health report

        Checks performed:
            1. Container runtime (Docker/Podman)
            2. Database container
            3. SQL Server connectivity
            4. sqlcmd CLI tool (optional)
        """
        components: list[ComponentHealth] = []

        # Check runtime
        components.extend([
            self.check_runtime(),
            self.check_container(),
            HealthChecker.check_sqlcmd_cli(),
            self.check_connectivity(),
        ])

        # Determine overall status
        unhealthy = [c for c in components if c.status == HealthStatus.UNHEALTHY]
        degraded = [c for c in components if c.status == HealthStatus.DEGRADED]

        if unhealthy:
            overall_status = HealthStatus.UNHEALTHY
        elif degraded:
            overall_status = HealthStatus.DEGRADED
        elif all(c.status in {HealthStatus.HEALTHY, HealthStatus.NOT_APPLICABLE} for c in components):
            overall_status = HealthStatus.HEALTHY
        else:
            overall_status = HealthStatus.UNKNOWN

        return SystemHealth(
            overall_status=overall_status,
            components=components,
            timestamp=datetime.now(UTC).isoformat(),
        )

    def check_runtime(self) -> ComponentHealth:
        """Check container runtime availability.

        Returns:
            ComponentHealth: Runtime status
        """
        if not self.runtime.is_available():
            return ComponentHealth(
                name="Container Runtime",
                status=HealthStatus.UNHEALTHY,
                message="no container runtime available",
                suggestions=[
                    "Install Docker: https://docs.docker.com/get-docker/",
                    "Or install Podman: https://podman.io/getting-started/installation",
                ],
            )

        runtime_type = self.runtime.get_runtime_type()
        return ComponentHealth(
            name="Container Runtime",
            status=HealthStatus.HEALTHY,
            message=f"{runtime_type.value} is available",
            details={"runtime": runtime_type.value},
        )

    def check_container(self) -> ComponentHealth:
        """Check database container status.

        Returns:
            ComponentHealth: Container status
        """
        from tools.sqlserver.database import DatabaseConfig

        config = DatabaseConfig.from_env()

        if not self.runtime.container_exists(config.container_name):
            return ComponentHealth(
                name="Database Container",
                status=HealthStatus.UNHEALTHY,
                message="container does not exist",
                suggestions=["Start container: python manage.py database sqlserver start"],
            )

        if not self.runtime.container_running(config.container_name):
            return ComponentHealth(
                name="Database Container",
                status=HealthStatus.DEGRADED,
                message="container exists but not running",
                suggestions=["Start container: python manage.py database sqlserver start"],
            )

        # Check health status
        try:
            _, stdout, _ = self.runtime.run_command(
                ["inspect", "--format", "{{.State.Health.Status}}", config.container_name],
                check=False,
            )
            health_status = stdout.strip()

            if health_status == "healthy":
                return ComponentHealth(
                    name="Database Container",
                    status=HealthStatus.HEALTHY,
                    message="container is running and healthy",
                    details={"container": config.container_name, "health": health_status},
                )

            if health_status == "starting":
                return ComponentHealth(
                    name="Database Container",
                    status=HealthStatus.DEGRADED,
                    message="container is starting",
                    details={"container": config.container_name, "health": health_status},
                    suggestions=["Wait for container to finish starting"],
                )

            return ComponentHealth(
                name="Database Container",
                status=HealthStatus.DEGRADED,
                message=f"container health status: {health_status}",
                details={"container": config.container_name, "health": health_status},
            )

        except Exception:  # noqa: BLE001
            return ComponentHealth(
                name="Database Container",
                status=HealthStatus.DEGRADED,
                message="container is running but health check unavailable",
                details={"container": config.container_name},
            )

    @staticmethod
    def check_sqlcmd_cli() -> ComponentHealth:
        """Check sqlcmd CLI availability.

        Returns:
            ComponentHealth: sqlcmd status
        """
        try:
            result = subprocess.run(
                ["sqlcmd", "-?"],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )

            if result.returncode == 0:
                return ComponentHealth(
                    name="sqlcmd CLI",
                    status=HealthStatus.HEALTHY,
                    message="sqlcmd is available",
                )

            return ComponentHealth(
                name="sqlcmd CLI",
                status=HealthStatus.NOT_APPLICABLE,
                message="sqlcmd not available (optional)",
                suggestions=["Install SQL Server client tools for sqlcmd access"],
            )

        except (subprocess.TimeoutExpired, FileNotFoundError):
            return ComponentHealth(
                name="sqlcmd CLI",
                status=HealthStatus.NOT_APPLICABLE,
                message="sqlcmd not available (optional)",
                suggestions=["Install SQL Server client tools for sqlcmd access"],
            )

    def check_connectivity(self) -> ComponentHealth:
        """Check database connectivity.

        Returns:
            ComponentHealth: Connectivity status
        """
        from tools.sqlserver.database import DatabaseConfig

        config = DatabaseConfig.from_env()

        # Only check if container is running
        if not self.runtime.container_running(config.container_name):
            return ComponentHealth(
                name="Database Connectivity",
                status=HealthStatus.UNHEALTHY,
                message="cannot check connectivity: container not running",
                suggestions=["Start container first"],
            )

        # Try sqlcmd via docker/podman exec
        try:
            cmd = self.runtime.get_runtime_command()
            result = subprocess.run(
                [
                    cmd,
                    "exec",
                    config.container_name,
                    "/opt/mssql-tools/bin/sqlcmd",
                    "-S",
                    "localhost",
                    "-U",
                    "sa",
                    "-P",
                    config.sa_password,
                    "-Q",
                    "SELECT 1",
                ],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )

            if result.returncode == 0:
                return ComponentHealth(
                    name="Database Connectivity",
                    status=HealthStatus.HEALTHY,
                    message="database is accepting connections",
                    details={
                        "host": "localhost",
                        "port": config.host_port,
                        "user": "sa",
                    },
                )

            return ComponentHealth(
                name="Database Connectivity",
                status=HealthStatus.DEGRADED,
                message="database not ready for connections",
                suggestions=["Wait for database to finish initializing"],
            )

        except Exception as e:  # noqa: BLE001
            return ComponentHealth(
                name="Database Connectivity",
                status=HealthStatus.UNHEALTHY,
                message=f"connection check failed: {e}",
                suggestions=["Check database logs: python manage.py database sqlserver logs"],
            )

    def display_health(
        self,
        health: SystemHealth,
        *,
        verbose: bool = False,
    ) -> None:
        """Display health report with Rich formatting.

        Args:
            health: System health information
            verbose: Show detailed information
        """
        # Overall status banner
        color = HealthChecker._get_status_color(health.overall_status)
        icon = HealthChecker._get_status_icon(health.overall_status)

        self.console.print()
        self.console.print(
            Panel(
                f"[{color}]{icon} System Status: {health.overall_status.value.upper()}[/{color}]",
                style=color,
                title="SQL Server Health Check",
            )
        )

        # Component table
        table = HealthChecker._create_component_table(health.components)
        self.console.print(table)

        # Suggestions for unhealthy components
        if health.unhealthy_components:
            self._display_suggestions(health)

        # Verbose details
        if verbose:
            for component in health.components:
                if component.details:
                    self.console.print(f"\n[bold]{component.name} Details:[/bold]")
                    for key, value in component.details.items():
                        self.console.print(f"  {key}: {value}")

        self.console.print()

    @staticmethod
    def _create_component_table(
        components: list[ComponentHealth],
    ) -> Table:
        """Create Rich table of component health."""
        table = Table(title="Component Health")
        table.add_column("Component", style="cyan")
        table.add_column("Status", style="white")
        table.add_column("Message", style="white")

        for component in components:
            color = HealthChecker._get_status_color(component.status)
            icon = HealthChecker._get_status_icon(component.status)
            status_str = f"[{color}]{icon} {component.status.value}[/{color}]"
            table.add_row(component.name, status_str, component.message)

        return table

    def _display_suggestions(
        self,
        health: SystemHealth,
    ) -> None:
        """Display troubleshooting suggestions."""
        self.console.print("\n[yellow]Troubleshooting Suggestions:[/yellow]")
        for component in health.unhealthy_components:
            if component.suggestions:
                self.console.print(f"\n[bold]{component.name}:[/bold]")
                for suggestion in component.suggestions:
                    self.console.print(f"  • {suggestion}")

    @staticmethod
    def _get_status_color(status: HealthStatus) -> str:
        """Get Rich color for status."""
        mapping = {
            HealthStatus.HEALTHY: "green",
            HealthStatus.DEGRADED: "yellow",
            HealthStatus.UNHEALTHY: "red",
            HealthStatus.UNKNOWN: "dim",
            HealthStatus.NOT_APPLICABLE: "dim",
        }
        return mapping.get(status, "white")

    @staticmethod
    def _get_status_icon(status: HealthStatus) -> str:
        """Get icon for status."""
        mapping = {
            HealthStatus.HEALTHY: "✓",
            HealthStatus.DEGRADED: "⚠",
            HealthStatus.UNHEALTHY: "✗",
            HealthStatus.UNKNOWN: "?",
            HealthStatus.NOT_APPLICABLE: "-",
        }
        return mapping.get(status, "?")
