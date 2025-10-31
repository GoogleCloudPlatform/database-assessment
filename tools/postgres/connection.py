"""Connection tester for PostgreSQL databases.

This module tests database connectivity for both managed containers
and external PostgreSQL instances.
"""

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
            - DATABASE_PORT (default: 15432 for managed, 5432 for external)
            - DATABASE_NAME (default: app)
            - DATABASE_URL (full connection string, overrides individual params)
        """
        mode = detect_deployment_mode()

        # Check for DATABASE_URL format (postgresql://user:password@host:port/database)
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            import re

            # Parse postgresql:// or postgres:// URLs
            match = re.match(
                r"(?:postgresql|postgres)://([^:]+):([^@]+)@([^:]+):(\d+)/(.+)",
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
        port = int(os.getenv("DATABASE_PORT", "15432" if mode == DeploymentMode.MANAGED else "5432"))
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
        port: int = 15432,
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
        port: int = 5432,
        database: str = "postgres",
        database_url: str | None = None,
    ) -> ConnectionConfig:
        """Create config for external PostgreSQL database."""
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
        """Get PostgreSQL connection string.

        Returns:
            str: Connection string in postgresql:// format
        """
        if self.database_url:
            return self.database_url

        return f"postgresql://{self.user}:{self.password}@{self.host}:{self.port}/{self.database}"


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
    """Test PostgreSQL database connections."""

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
            5. Database extensions (if available)
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
            # Test connection with asyncpg
            import asyncio

            import asyncpg

            async def test_async() -> ConnectionTestResult:
                try:
                    conn = await asyncpg.connect(
                        user=config.user,
                        password=config.password,
                        host=config.host,
                        port=config.port,
                        database=config.database,
                        timeout=timeout,
                    )

                    try:
                        # Execute test query
                        await conn.fetchval("SELECT 'OK'")

                        # Get server version
                        version_row = await conn.fetchrow("SELECT version()")
                        server_version = str(version_row["version"] if version_row else "unknown")

                        # Get database info
                        db_info: dict[str, Any] = {"version": server_version}

                        # Check for pgvector extension
                        try:
                            pgvector_check = await conn.fetchval(
                                "SELECT EXISTS(SELECT 1 FROM pg_extension WHERE extname = 'vector')"
                            )
                            db_info["pgvector_installed"] = bool(pgvector_check)
                        except asyncpg.PostgresError:
                            db_info["pgvector_installed"] = False

                        connection_time_ms = (time.time() - start_time) * 1000

                        mode_desc = (
                            "managed container" if config.mode == DeploymentMode.MANAGED else "external database"
                        )
                        message = (
                            f"successfully connected to {mode_desc}: {config.host}:{config.port}/{config.database}"
                        )

                        return ConnectionTestResult(
                            success=True,
                            mode=config.mode,
                            message=message,
                            connection_time_ms=connection_time_ms,
                            server_version=server_version,
                            database_info=db_info,
                        )

                    finally:
                        await conn.close()

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

            # Run async test
            return asyncio.run(test_async())

        except ImportError:
            return ConnectionTestResult(
                success=False,
                mode=config.mode,
                message="asyncpg library not installed",
                error="asyncpg package required for PostgreSQL connections",
                suggestions=["Install asyncpg: uv add asyncpg"],
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
                    "Ensure container is running: python manage.py database postgres status",
                    "Start container: python manage.py database postgres start",
                ])
            else:
                suggestions.extend([
                    "Check if PostgreSQL server is running",
                    f"Verify host and port: {config.host}:{config.port}",
                ])

        elif "authentication failed" in error_lower or "password" in error_lower:
            suggestions.extend([
                "Verify DATABASE_USER and DATABASE_PASSWORD",
                "Check credentials in environment variables",
            ])

        elif "database" in error_lower and "does not exist" in error_lower:
            suggestions.extend([
                f"Create database: psql -U {config.user} -c 'CREATE DATABASE {config.database}'",
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
                "Review PostgreSQL server logs",
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
            if result.connection_time_ms or result.server_version or result.database_info:
                table = Table(title="Connection Details")
                table.add_column("Property", style="cyan")
                table.add_column("Value", style="white")

                if result.connection_time_ms:
                    table.add_row("Connection Time", f"{result.connection_time_ms:.2f} ms")

                if result.server_version:
                    # Shorten version for display
                    version_short = result.server_version.split("\n")[0][:80]
                    table.add_row("Server Version", version_short)

                if result.database_info:
                    for key, value in result.database_info.items():
                        if key != "version":  # Already shown
                            display_key = key.replace("_", " ").title()
                            table.add_row(display_key, str(value))

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
        table = Table(title="PostgreSQL Connection Information")
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
