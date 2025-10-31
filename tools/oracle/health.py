"""Health checker for Oracle deployment components.

This module checks the health and status of all Oracle deployment
components across both modes (managed, external).
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import TYPE_CHECKING, Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table

from tools.lib.container import ContainerRuntime
from tools.oracle.connection import ConnectionTester, DeploymentMode
from tools.oracle.sqlcl_installer import SQLclInstaller
from tools.oracle.wallet import WalletConfigurator

if TYPE_CHECKING:
    from pathlib import Path


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
    deployment_mode: DeploymentMode | None
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
    """Check health of Oracle deployment components."""

    def __init__(self, console: Console | None = None) -> None:
        """Initialize health checker.

        Args:
            console: Rich console for output (creates new if None)
        """
        self.console = console or Console()
        self.runtime = ContainerRuntime()
        self.connection_tester = ConnectionTester(console=self.console)
        self.wallet_configurator = WalletConfigurator(console=self.console)
        self.sqlcl_installer = SQLclInstaller(console=self.console)

    def check_all(
        self,
        *,
        deployment_mode: DeploymentMode | None = None,
        verbose: bool = False,
    ) -> SystemHealth:
        """Check health of all components.

        Args:
            deployment_mode: Specific mode to check (auto-detect if None)
            verbose: Include detailed diagnostic information

        Returns:
            SystemHealth: Comprehensive health report

        Checks performed:
            1. Container runtime (if managed mode)
            2. Database container (if managed mode)
            3. SQLcl installation
            4. Wallet configuration (if wallet configured)
            5. Database connectivity
        """
        from datetime import UTC, datetime

        # Auto-detect mode if not specified
        if deployment_mode is None:
            deployment_mode = HealthChecker.detect_deployment_mode()

        components: list[ComponentHealth] = []

        # Check runtime and container for MANAGED mode
        if deployment_mode == DeploymentMode.MANAGED:
            components.extend([self.check_runtime(), self.check_container()])

        # Check SQLcl (optional for all modes)
        components.append(self.check_sqlcl())

        # Check wallet (if configured - auto-detected)
        wallet_health = self.check_wallet()
        if wallet_health.status != HealthStatus.NOT_APPLICABLE:
            components.append(wallet_health)

        # Check connectivity (for all modes)
        components.append(self.check_connectivity(deployment_mode))

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
            deployment_mode=deployment_mode,
            components=components,
            timestamp=datetime.now(UTC).isoformat(),
        )

    def check_runtime(self) -> ComponentHealth:
        """Check container runtime availability.

        Returns:
            ComponentHealth: Runtime status

        Checks:
            - Docker or Podman available
            - Runtime is responsive
            - Version information
        """
        if not self.runtime.is_available():
            return ComponentHealth(
                name="Container Runtime",
                status=HealthStatus.UNHEALTHY,
                message="No container runtime available",
                suggestions=["Install Docker or Podman"],
            )

        runtime_type = self.runtime.get_runtime_type()
        return ComponentHealth(
            name="Container Runtime",
            status=HealthStatus.HEALTHY,
            message=f"{runtime_type.value.capitalize()} is available",
            details={"runtime": runtime_type.value},
        )

    def check_container(self) -> ComponentHealth:
        """Check local database container status.

        Returns:
            ComponentHealth: Container status

        Checks:
            - Container exists
            - Container is running
            - Container is healthy
            - Port is accessible
        """
        from tools.oracle.database import DatabaseConfig

        config = DatabaseConfig.from_env()

        if not self.runtime.container_exists(config.container_name):
            return ComponentHealth(
                name="Database Container",
                status=HealthStatus.UNHEALTHY,
                message="Container does not exist",
                suggestions=["Start container: uv run python tools/oracle_deploy.py database start"],
            )

        if not self.runtime.container_running(config.container_name):
            return ComponentHealth(
                name="Database Container",
                status=HealthStatus.DEGRADED,
                message="Container exists but not running",
                suggestions=["Start container: uv run python tools/oracle_deploy.py database start"],
            )

        # Check health status
        status = self.runtime.get_container_status(config.container_name)
        if status:
            status_str = str(status)  # Convert to string explicitly
            if "healthy" in status_str.lower():
                return ComponentHealth(
                    name="Database Container",
                    status=HealthStatus.HEALTHY,
                    message="Container is running and healthy",
                    details={"container": config.container_name, "status": status_str},
                )

        return ComponentHealth(
            name="Database Container",
            status=HealthStatus.DEGRADED,
            message="Container is running but health status unknown",
            details={"container": config.container_name},
        )

    def check_sqlcl(self) -> ComponentHealth:
        """Check SQLcl installation.

        Returns:
            ComponentHealth: SQLcl status

        Checks:
            - SQLcl is installed
            - sql command is in PATH
            - Version information
        """
        if not self.sqlcl_installer.is_installed():
            return ComponentHealth(
                name="SQLcl",
                status=HealthStatus.NOT_APPLICABLE,
                message="SQLcl not installed (optional)",
                suggestions=["Install: uv run python tools/oracle_deploy.py sqlcl install"],
            )

        version = self.sqlcl_installer.get_version()
        in_path = self.sqlcl_installer.is_in_path()

        if in_path:
            return ComponentHealth(
                name="SQLcl",
                status=HealthStatus.HEALTHY,
                message=f"SQLcl {version} installed and in PATH",
                details={"version": version, "in_path": True},
            )

        instructions = self.sqlcl_installer.get_path_instructions()
        # Convert str to list[str] for suggestions
        suggestions_list: list[str] = [instructions]

        return ComponentHealth(
            name="SQLcl",
            status=HealthStatus.DEGRADED,
            message=f"SQLcl {version} installed but not in PATH",
            details={"version": version, "in_path": False},
            suggestions=suggestions_list,
        )

    def check_wallet(self, wallet_dir: Path | None = None) -> ComponentHealth:
        """Check wallet configuration.

        Args:
            wallet_dir: Wallet directory (auto-detect if None)

        Returns:
            ComponentHealth: Wallet status (NOT_APPLICABLE if no wallet configured)

        Checks:
            - Wallet directory exists
            - Required files present
            - tnsnames.ora is valid
            - TNS_ADMIN is set (if needed)
        """
        import os

        # Check if wallet is configured in environment
        if wallet_dir is None and not (os.getenv("WALLET_LOCATION") or os.getenv("TNS_ADMIN")):
            return ComponentHealth(
                name="Wallet",
                status=HealthStatus.NOT_APPLICABLE,
                message="No wallet configured (using standard connection)",
            )

        if wallet_dir is None:
            found = self.wallet_configurator.find_wallet()
            if not found:
                return ComponentHealth(
                    name="Wallet",
                    status=HealthStatus.UNHEALTHY,
                    message="Wallet configured but not found",
                    suggestions=["Extract wallet: python manage.py wallet extract <wallet.zip>"],
                )
            wallet_dir = found if found.is_dir() else self.wallet_configurator.extract_wallet(found)

        wallet_info = self.wallet_configurator.validate_wallet(wallet_dir)

        if wallet_info.is_valid:
            return ComponentHealth(
                name="Wallet",
                status=HealthStatus.HEALTHY,
                message=f"Wallet valid with {len(wallet_info.services or [])} services",
                details={"wallet_dir": str(wallet_dir), "services": len(wallet_info.services or [])},
            )

        return ComponentHealth(
            name="Wallet",
            status=HealthStatus.UNHEALTHY,
            message="Wallet validation failed",
            details={"errors": wallet_info.validation_errors},
            suggestions=["Validate wallet: python manage.py wallet validate"],
        )

    def check_connectivity(
        self,
        mode: DeploymentMode | None = None,
    ) -> ComponentHealth:
        """Check database connectivity.

        Args:
            mode: Deployment mode (auto-detect if None)

        Returns:
            ComponentHealth: Connectivity status

        Attempts database connection based on mode:
            - LOCAL: Connect to container
            - REMOTE: Connect to remote host
            - AUTONOMOUS: Connect with wallet
        """
        from tools.oracle.connection import ConnectionConfig

        try:
            config = ConnectionConfig.from_env()
            if mode:
                config.mode = mode

            result = self.connection_tester.test(config, timeout=5, display=False)

            if result.success:
                return ComponentHealth(
                    name="Database Connectivity",
                    status=HealthStatus.HEALTHY,
                    message=result.message,
                    details={
                        "mode": config.mode.value,
                        "connection_time_ms": result.connection_time_ms,
                        "server_version": result.server_version,
                    },
                )

            return ComponentHealth(
                name="Database Connectivity",
                status=HealthStatus.UNHEALTHY,
                message=result.message,
                details={"mode": config.mode.value},
                suggestions=result.suggestions,
            )

        except Exception as e:  # noqa: BLE001
            return ComponentHealth(
                name="Database Connectivity",
                status=HealthStatus.UNHEALTHY,
                message=f"Connection test failed: {e}",
                suggestions=["Check configuration and try: uv run python tools/oracle_deploy.py connect test"],
            )

    @staticmethod
    def detect_deployment_mode() -> DeploymentMode | None:
        """Auto-detect deployment mode.

        Returns:
            DeploymentMode | None: Detected mode

        Detection logic:
            - If DATABASE_HOST or DATABASE_URL is set -> EXTERNAL
            - Otherwise -> MANAGED (Docker container)
        """
        from tools.oracle.connection import detect_deployment_mode

        return detect_deployment_mode()

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

        Output includes:
            - Overall status banner
            - Component status table
            - Detailed information (if verbose)
            - Troubleshooting suggestions for failures
        """
        # Overall status banner
        color = HealthChecker.get_status_color(health.overall_status)
        icon = HealthChecker.get_status_icon(health.overall_status)
        mode_str = f" ({health.deployment_mode.value})" if health.deployment_mode else ""

        self.console.print()
        self.console.print(
            Panel(
                f"[{color}]{icon} System Status: {health.overall_status.value.upper()}{mode_str}[/{color}]",
                style=color,
            )
        )

        # Component table
        table = HealthChecker.display_component_table(health.components)
        self.console.print(table)

        # Suggestions for unhealthy components
        if health.unhealthy_components:
            self.display_suggestions(health)

        # Verbose details
        if verbose:
            for component in health.components:
                if component.details:
                    self.console.print(f"\n[bold]{component.name} Details:[/bold]")
                    for key, value in component.details.items():
                        self.console.print(f"  {key}: {value}")

        self.console.print()

    @staticmethod
    def display_component_table(
        components: list[ComponentHealth],
    ) -> Table:
        """Create Rich table of component health.

        Args:
            components: List of component health statuses

        Returns:
            Table: Formatted component table

        Columns:
            - Component name
            - Status (with color coding)
            - Message
        """
        table = Table(title="Component Health")
        table.add_column("Component", style="cyan")
        table.add_column("Status", style="white")
        table.add_column("Message", style="white")

        for component in components:
            color = HealthChecker.get_status_color(component.status)
            icon = HealthChecker.get_status_icon(component.status)
            status_str = f"[{color}]{icon} {component.status.value}[/{color}]"
            table.add_row(component.name, status_str, component.message)

        return table

    def display_suggestions(
        self,
        health: SystemHealth,
    ) -> None:
        """Display troubleshooting suggestions.

        Args:
            health: System health information

        Shows suggestions for unhealthy components.
        """
        self.console.print("\n[yellow]Troubleshooting Suggestions:[/yellow]")
        for component in health.unhealthy_components:
            if component.suggestions:
                self.console.print(f"\n[bold]{component.name}:[/bold]")
                for suggestion in component.suggestions:
                    self.console.print(f"  • {suggestion}")

    @staticmethod
    def get_status_color(status: HealthStatus) -> str:
        """Get Rich color for status.

        Args:
            status: Health status

        Returns:
            str: Rich color name

        Mapping:
            - HEALTHY: green
            - DEGRADED: yellow
            - UNHEALTHY: red
            - UNKNOWN: dim
            - NOT_APPLICABLE: dim
        """
        mapping = {
            HealthStatus.HEALTHY: "green",
            HealthStatus.DEGRADED: "yellow",
            HealthStatus.UNHEALTHY: "red",
            HealthStatus.UNKNOWN: "dim",
            HealthStatus.NOT_APPLICABLE: "dim",
        }
        return mapping.get(status, "white")

    @staticmethod
    def get_status_icon(status: HealthStatus) -> str:
        """Get icon for status.

        Args:
            status: Health status

        Returns:
            str: Status icon

        Mapping:
            - HEALTHY: ✓
            - DEGRADED: ⚠
            - UNHEALTHY: ✗
            - UNKNOWN: ?
            - NOT_APPLICABLE: -
        """
        mapping = {
            HealthStatus.HEALTHY: "✓",
            HealthStatus.DEGRADED: "⚠",
            HealthStatus.UNHEALTHY: "✗",
            HealthStatus.UNKNOWN: "?",
            HealthStatus.NOT_APPLICABLE: "-",
        }
        return mapping.get(status, "?")


def get_troubleshooting_suggestions(
    component: ComponentHealth,
) -> list[str]:
    """Get troubleshooting suggestions for component.

    Args:
        component: Component health information

    Returns:
        list[str]: Suggested actions

    Provides specific suggestions based on:
        - Component type
        - Failure reason
        - System state
    """
    # Return component's own suggestions if available
    if component.suggestions:
        return component.suggestions

    # Provide generic suggestions based on component name
    if "Container Runtime" in component.name:
        return ["Install Docker or Podman", "Ensure container runtime is running"]
    if "Database Container" in component.name:
        return ["Start container: uv run python tools/oracle_deploy.py database start"]
    if "SQLcl" in component.name:
        return ["Install SQLcl: uv run python tools/oracle_deploy.py sqlcl install"]
    if "Wallet" in component.name:
        return ["Configure wallet: uv run python tools/oracle_deploy.py wallet configure"]
    if "Connectivity" in component.name:
        return ["Test connection: uv run python tools/oracle_deploy.py connect test"]

    return ["Check component configuration and try again"]
