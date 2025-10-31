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
"""Connection tester for MySQL databases."""

from __future__ import annotations

import os
from dataclasses import dataclass
from enum import Enum
from typing import Any

from rich.console import Console
from rich.panel import Panel
from rich.table import Table


class DeploymentMode(str, Enum):
    """Database deployment modes."""

    MANAGED = "managed"  # We manage a Docker/Podman container
    EXTERNAL = "external"  # Connect to existing database


@dataclass
class ConnectionConfig:
    """Database connection configuration."""

    # Mode
    mode: DeploymentMode

    # Connection settings
    user: str
    password: str
    host: str
    port: int
    database: str
    database_url: str | None = None

    @classmethod
    def from_env(cls) -> ConnectionConfig:
        """Create connection config from environment variables.

        Returns:
            ConnectionConfig: Configuration from environment

        Detection logic:
            - If DATABASE_HOST or DATABASE_URL is set -> EXTERNAL mode
            - Otherwise -> MANAGED mode (local container)

        Environment variables:
            - DATABASE_USER (default: app)
            - DATABASE_PASSWORD (default: super-secret for managed, empty for external)
            - DATABASE_HOST (default: localhost for managed)
            - DATABASE_PORT (default: 3306 for managed, 3306 for external)
            - DATABASE_NAME (default: app)
            - DATABASE_URL (full connection string, overrides individual params)
        """
        mode = detect_deployment_mode()

        # Check for DATABASE_URL format (mysql://user:password@host:port/database)
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            import re

            match = re.match(
                r"mysql://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)",
                database_url,
            )
            if match:
                user, password, host, port, database = match.groups()
                return cls(
                    mode=mode,
                    user=user,
                    password=password,
                    host=host,
                    port=int(port),
                    database=database,
                    database_url=database_url,
                )

        # Standard connection parameters
        user = os.getenv("DATABASE_USER", "app")
        password = os.getenv(
            "DATABASE_PASSWORD",
            "super-secret" if mode == DeploymentMode.MANAGED else "",
        )
        host = os.getenv("DATABASE_HOST", "localhost" if mode == DeploymentMode.MANAGED else "")
        port = int(os.getenv("DATABASE_PORT", "3306"))
        database = os.getenv("DATABASE_NAME", "app")

        return cls(
            mode=mode,
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
        )

    @classmethod
    def for_managed(
        cls,
        user: str = "app",
        password: str = "super-secret",
        host: str = "localhost",
        port: int = 3306,
        database: str = "app",
    ) -> ConnectionConfig:
        """Create config for managed Docker/Podman container."""
        return cls(
            mode=DeploymentMode.MANAGED,
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
        )

    @classmethod
    def for_external(
        cls,
        user: str,
        password: str,
        host: str,
        port: int = 3306,
        database: str = "mysql",
        database_url: str | None = None,
    ) -> ConnectionConfig:
        """Create config for external MySQL database."""
        return cls(
            mode=DeploymentMode.EXTERNAL,
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
            database_url=database_url,
        )

    def get_connection_string(self) -> str:
        """Get MySQL connection string.

        Returns:
            str: Connection string in mysql:// format
        """
        if self.database_url:
            return self.database_url

        return f"mysql://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}"


@dataclass
class ConnectionTestResult:
    """Result of connection test."""

    success: bool
    mode: DeploymentMode
    message: str
    connection_time_ms: float | None = None
    server_version: str | None = None
    database_info: dict[str, Any] | None = None
    error: str | None = None
    suggestions: list[str] | None = None


@dataclass
class ConnectionInfo:
    """Detailed connection information."""

    mode: DeploymentMode
    host: str
    port: int
    database: str
    user: str
    connection_string: str


class ConnectionTester:
    """Test MySQL database connections."""

    def __init__(self, console: Console | None = None) -> None:
        """Initialize connection tester.

        Args:
            console: Rich console for output (creates new if None)
        """
        self.console = console or Console()

    def test(
        self,
        config: ConnectionConfig | None = None,
        *,
        timeout: int = 10,
        display: bool = True,
    ) -> ConnectionTestResult:
        """Test database connection.

        Args:
            config: Connection configuration (reads from env if None)
            timeout: Connection timeout in seconds
            display: Display results with Rich formatting

        Returns:
            ConnectionTestResult: Test results

        Tests performed:
            1. Basic connectivity
            2. Authentication
            3. Query execution (simple SELECT)
            4. Server version
        """
        if config is None:
            config = ConnectionConfig.from_env()

        result = self._do_connection_test(config, timeout)

        if display:
            self.display_test_result(result)

        return result

    def _do_connection_test(
        self,
        config: ConnectionConfig,
        timeout: int = 10,
    ) -> ConnectionTestResult:
        """Execute connection test.

        Args:
            config: Connection configuration
            timeout: Connection timeout in seconds

        Returns:
            ConnectionTestResult: Test results
        """
        import time

        start_time = time.time()

        try:
            import mysql.connector

            try:
                conn = mysql.connector.connect(
                    user=config.user,
                    password=config.password,
                    host=config.host,
                    port=config.port,
                    database=config.database,
                    connection_timeout=timeout,
                )

                try:
                    # Execute test query
                    cursor = conn.cursor()
                    cursor.execute("SELECT 'OK'")
                    cursor.fetchone()

                    # Get server version
                    cursor.execute("SELECT VERSION()")
                    server_version = cursor.fetchone()[0]

                    connection_time_ms = (time.time() - start_time) * 1000

                    mode_desc = "managed container" if config.mode == DeploymentMode.MANAGED else "external database"
                    message = f"successfully connected to {mode_desc}: {config.host}:{config.port}/{config.database}"

                    return ConnectionTestResult(
                        success=True,
                        mode=config.mode,
                        message=message,
                        connection_time_ms=connection_time_ms,
                        server_version=server_version,
                        database_info={"version": server_version},
                    )

                finally:
                    conn.close()

            except Exception as e:  # noqa: BLE001
                error_msg = str(e)
                suggestions = self._get_error_suggestions(error_msg, config)

                return ConnectionTestResult(
                    success=False,
                    mode=config.mode,
                    message=f"connection failed: {error_msg}",
                    error=error_msg,
                    suggestions=suggestions,
                )

        except ImportError:
            return ConnectionTestResult(
                success=False,
                mode=config.mode,
                message="mysql-connector-python library not installed",
                error="mysql-connector-python package required for MySQL connections",
                suggestions=["Install mysql-connector-python: uv add mysql-connector-python"],
            )

        except Exception as e:  # noqa: BLE001
            error_msg = str(e)
            suggestions = self._get_error_suggestions(error_msg, config)

            return ConnectionTestResult(
                success=False,
                mode=config.mode,
                message=f"connection test failed: {error_msg}",
                error=error_msg,
                suggestions=suggestions,
            )

    @staticmethod
    def _get_error_suggestions(
        error: str,
        config: ConnectionConfig,
    ) -> list[str]:
        """Get troubleshooting suggestions based on error.

        Args:
            error: Error message
            config: Connection configuration

        Returns:
            list[str]: Suggested actions
        """
        suggestions = []
        error_lower = error.lower()

        if "connection refused" in error_lower or "could not connect" in error_lower:
            if config.mode == DeploymentMode.MANAGED:
                suggestions.extend([
                    "Ensure container is running: python manage.py database mysql status",
                    "Start container: python manage.py database mysql start",
                ])
            else:
                suggestions.extend([
                    "Check if MySQL server is running",
                    f"Verify host and port: {config.host}:{config.port}",
                ])

        elif "access denied" in error_lower or "password" in error_lower:
            suggestions.extend([
                "Verify DATABASE_USER and DATABASE_PASSWORD",
                "Check credentials in environment variables",
            ])

        elif "unknown database" in error_lower:
            suggestions.extend([
                f"Create database: mysql -u {config.user} -p -e 'CREATE DATABASE {config.database}'",
                "Or use an existing database name",
            ])

        elif "timeout" in error_lower:
            suggestions.extend([
                "Check network connectivity",
                "Increase timeout value",
                "Verify firewall settings",
            ])

        else:
            suggestions.extend([
                "Check connection parameters",
                "Review MySQL server logs",
                "Verify network connectivity",
            ])

        return suggestions

    def display_test_result(self, result: ConnectionTestResult) -> None:
        """Display connection test result with Rich formatting.

        Args:
            result: Connection test result
        """
        if result.success:
            self.console.print()
            self.console.print(
                Panel(
                    f"[green]✓ {result.message}[/green]",
                    style="green",
                    title="Connection Test Success",
                )
            )

            # Details table
            if result.connection_time_ms or result.server_version:
                table = Table(title="Connection Details")
                table.add_column("Property", style="cyan")
                table.add_column("Value", style="white")

                if result.connection_time_ms:
                    table.add_row("Connection Time", f"{result.connection_time_ms:.2f} ms")

                if result.server_version:
                    table.add_row("Server Version", result.server_version)

                self.console.print(table)

        else:
            self.console.print()
            self.console.print(
                Panel(
                    f"[red]✗ {result.message}[/red]",
                    style="red",
                    title="Connection Test Failed",
                )
            )

            if result.suggestions:
                self.console.print("\n[yellow]Suggestions:[/yellow]")
                for suggestion in result.suggestions:
                    self.console.print(f"  • {suggestion}")

        self.console.print()

    @staticmethod
    def get_connection_info(
        config: ConnectionConfig | None = None,
    ) -> ConnectionInfo:
        """Get connection information without testing.

        Args:
            config: Connection configuration (reads from env if None)

        Returns:
            ConnectionInfo: Connection details
        """
        if config is None:
            config = ConnectionConfig.from_env()

        return ConnectionInfo(
            mode=config.mode,
            host=config.host,
            port=config.port,
            database=config.database,
            user=config.user,
            connection_string=config.get_connection_string(),
        )

    def display_connection_info(
        self,
        info: ConnectionInfo,
    ) -> None:
        """Display connection information.

        Args:
            info: Connection information
        """
        table = Table(title="MySQL Connection Information")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="white")

        table.add_row("Deployment Mode", info.mode.value)
        table.add_row("Host", info.host)
        table.add_row("Port", str(info.port))
        table.add_row("Database", info.database)
        table.add_row("User", info.user)
        table.add_row("Connection String", info.connection_string)

        self.console.print()
        self.console.print(table)
        self.console.print()


def detect_deployment_mode() -> DeploymentMode:
    """Auto-detect deployment mode from environment.

    Returns:
        DeploymentMode: Detected mode

    Logic:
        - If DATABASE_HOST or DATABASE_URL is set -> EXTERNAL
        - Otherwise -> MANAGED (local container)
    """
    has_url = bool(os.getenv("DATABASE_URL"))
    has_host = bool(os.getenv("DATABASE_HOST"))

    if has_url or has_host:
        return DeploymentMode.EXTERNAL

    return DeploymentMode.MANAGED
