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
"""Connection tester for SQL Server databases."""

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
    driver: str
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
            - DATABASE_USER (default: sa)
            - DATABASE_PASSWORD (default: super-secret-password-123 for managed, empty for external)
            - DATABASE_HOST (default: localhost for managed)
            - DATABASE_PORT (default: 1433 for managed, 1433 for external)
            - DATABASE_NAME (default: master)
            - DATABASE_DRIVER (default: ODBC Driver 17 for SQL Server)
            - DATABASE_URL (full connection string, overrides individual params)
        """
        mode = detect_deployment_mode()

        # Check for DATABASE_URL format
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            import re

            match = re.match(
                r"mssql\\+pyodbc://([^:]+):([^@]+)@([^:]+):(\d+)/([^?]+)\\?driver=(.+)",
                database_url,
            )
            if match:
                user, password, host, port, database, driver = match.groups()
                return cls(
                    mode=mode,
                    user=user,
                    password=password,
                    host=host,
                    port=int(port),
                    database=database,
                    driver=driver,
                    database_url=database_url,
                )

        # Standard connection parameters
        user = os.getenv("DATABASE_USER", "sa")
        password = os.getenv(
            "DATABASE_PASSWORD",
            "super-secret-password-123" if mode == DeploymentMode.MANAGED else "",
        )
        host = os.getenv("DATABASE_HOST", "localhost" if mode == DeploymentMode.MANAGED else "")
        port = int(os.getenv("DATABASE_PORT", "1433"))
        database = os.getenv("DATABASE_NAME", "master")
        driver = os.getenv("DATABASE_DRIVER", "ODBC Driver 17 for SQL Server")

        return cls(
            mode=mode,
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
            driver=driver,
        )

    @classmethod
    def for_managed(
        cls,
        user: str = "sa",
        password: str = "super-secret-password-123",
        host: str = "localhost",
        port: int = 1433,
        database: str = "master",
        driver: str = "ODBC Driver 17 for SQL Server",
    ) -> ConnectionConfig:
        """Create config for managed Docker/Podman container."""
        return cls(
            mode=DeploymentMode.MANAGED,
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
            driver=driver,
        )

    @classmethod
    def for_external(
        cls,
        user: str,
        password: str,
        host: str,
        port: int = 1433,
        database: str = "master",
        driver: str = "ODBC Driver 17 for SQL Server",
        database_url: str | None = None,
    ) -> ConnectionConfig:
        """Create config for external SQL Server database."""
        return cls(
            mode=DeploymentMode.EXTERNAL,
            user=user,
            password=password,
            host=host,
            port=port,
            database=database,
            driver=driver,
            database_url=database_url,
        )

    def get_connection_string(self) -> str:
        """Get SQL Server connection string.

        Returns:
            str: Connection string in mssql+pyodbc:// format
        """
        if self.database_url:
            return self.database_url

        return (
            f"mssql+pyodbc://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}?driver={self.driver}"
        )


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
    driver: str
    connection_string: str


class ConnectionTester:
    """Test SQL Server database connections."""

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

        result = ConnectionTester._do_connection_test(config, timeout)

        if display:
            self.display_test_result(result)

        return result

    @staticmethod
    def _do_connection_test(
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
            from sqlalchemy import create_engine

            try:
                engine = create_engine(config.get_connection_string(), connect_args={"timeout": timeout})
                with engine.connect() as conn:
                    # Execute test query
                    result = conn.execute("SELECT 'OK'")
                    result.fetchone()

                    # Get server version
                    result = conn.execute("SELECT @@VERSION")
                    server_version = result.fetchone()[0]

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

            except Exception as e:  # noqa: BLE001
                error_msg = str(e)
                suggestions = ConnectionTester._get_error_suggestions(error_msg, config)

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
                message="pyodbc library not installed",
                error="pyodbc package required for SQL Server connections",
                suggestions=["Install pyodbc: uv add pyodbc"],
            )

        except Exception as e:  # noqa: BLE001
            error_msg = str(e)
            suggestions = ConnectionTester._get_error_suggestions(error_msg, config)

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
                    "Ensure container is running: python manage.py database sqlserver status",
                    "Start container: python manage.py database sqlserver start",
                ])
            else:
                suggestions.extend([
                    "Check if SQL Server is running",
                    f"Verify host and port: {config.host}:{config.port}",
                ])

        elif "login failed" in error_lower or "password" in error_lower:
            suggestions.extend([
                "Verify DATABASE_USER and DATABASE_PASSWORD",
                "Check credentials in environment variables",
            ])

        elif "cannot open database" in error_lower:
            suggestions.extend([
                f"Create database: sqlcmd -S {config.host} -U {config.user} -P {config.password} -Q 'CREATE DATABASE {config.database}'",
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
                "Review SQL Server logs",
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
                    table.add_row("Server Version", result.server_version.split("\n")[0])

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
            driver=config.driver,
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
        table = Table(title="SQL Server Connection Information")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="white")

        table.add_row("Deployment Mode", info.mode.value)
        table.add_row("Host", info.host)
        table.add_row("Port", str(info.port))
        table.add_row("Database", info.database)
        table.add_row("User", info.user)
        table.add_row("Driver", info.driver)
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
