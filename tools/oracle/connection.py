"""Connection tester for Oracle databases.

This module tests database connectivity across all deployment modes:
local, remote, and autonomous.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any

from rich.console import Console
from rich.table import Table


class DeploymentMode(str, Enum):
    """Database deployment modes."""

    MANAGED = "managed"  # We manage a Docker container
    EXTERNAL = "external"  # Connect to existing database (auto-detect wallet)


@dataclass
class ConnectionConfig:
    """Database connection configuration."""

    # Mode
    mode: DeploymentMode

    # Common settings
    user: str
    password: str

    # Local/Remote settings
    host: str | None = None
    port: int | None = None
    service_name: str | None = None
    dsn: str | None = None

    # Autonomous settings
    wallet_location: Path | None = None
    wallet_password: str | None = None
    database_url: str | None = None

    @classmethod
    def from_env(cls) -> ConnectionConfig:
        """Create connection config from environment variables.

        Returns:
            ConnectionConfig: Configuration from environment

        Detection logic:
            - If DATABASE_HOST or DATABASE_URL is set -> EXTERNAL mode
            - Otherwise -> MANAGED mode (local Docker container)
            - Wallet is auto-detected if WALLET_LOCATION/TNS_ADMIN is set

        Environment variables:
            # Connection (all modes)
            - DATABASE_USER
            - DATABASE_PASSWORD
            - DATABASE_HOST (or DATABASE_URL for connection string)
            - DATABASE_PORT
            - DATABASE_SERVICE_NAME
            - DATABASE_DSN

            # Wallet (auto-detected when present)
            - WALLET_LOCATION or TNS_ADMIN
            - WALLET_PASSWORD

            # Managed mode defaults
            - Uses localhost:1521/FREEPDB1 if no DATABASE_HOST/URL set
        """
        mode = detect_deployment_mode()

        # Check for wallet (independent of mode)
        wallet_location = os.getenv("WALLET_LOCATION") or os.getenv("TNS_ADMIN")
        wallet_password = os.getenv("WALLET_PASSWORD")

        # Handle DATABASE_URL format (e.g., oracle+oracledb://user:password@service_name)
        database_url = os.getenv("DATABASE_URL")
        if database_url:
            import re

            match = re.match(r"oracle\+oracledb://([^:]+):([^@]+)@(.+)", database_url)
            if match:
                user, password, service_name = match.groups()
                return cls(
                    mode=mode,
                    user=user,
                    password=password,
                    service_name=service_name,
                    database_url=database_url,
                    wallet_location=Path(wallet_location) if wallet_location else None,
                    wallet_password=wallet_password,
                )

        # Standard connection parameters
        user = os.getenv("DATABASE_USER", os.getenv("ORACLE_USER", "app"))
        password = os.getenv(
            "DATABASE_PASSWORD", os.getenv("ORACLE_PASSWORD", "super-secret" if mode == DeploymentMode.MANAGED else "")
        )
        host = os.getenv("DATABASE_HOST", "localhost" if mode == DeploymentMode.MANAGED else "")
        port = int(os.getenv("DATABASE_PORT", os.getenv("ORACLE23AI_PORT", "1521")))
        service_name = os.getenv("DATABASE_SERVICE_NAME", "FREEPDB1" if mode == DeploymentMode.MANAGED else "ORCL")
        dsn = os.getenv("DATABASE_DSN")

        return cls(
            mode=mode,
            user=user,
            password=password,
            host=host,
            port=port,
            service_name=service_name,
            dsn=dsn,
            wallet_location=Path(wallet_location) if wallet_location else None,
            wallet_password=wallet_password,
        )

    @classmethod
    def for_managed(
        cls,
        user: str = "app",
        password: str = "super-secret",
        host: str = "localhost",
        port: int = 1521,
        service_name: str = "FREEPDB1",
    ) -> ConnectionConfig:
        """Create config for managed Docker container database."""
        return cls(
            mode=DeploymentMode.MANAGED,
            user=user,
            password=password,
            host=host,
            port=port,
            service_name=service_name,
        )

    @classmethod
    def for_external(
        cls,
        user: str,
        password: str,
        host: str | None = None,
        port: int = 1521,
        service_name: str = "ORCL",
        database_url: str | None = None,
        wallet_location: Path | None = None,
        wallet_password: str | None = None,
    ) -> ConnectionConfig:
        """Create config for external database (with optional wallet support)."""
        return cls(
            mode=DeploymentMode.EXTERNAL,
            user=user,
            password=password,
            host=host,
            port=port,
            service_name=service_name,
            database_url=database_url,
            wallet_location=wallet_location,
            wallet_password=wallet_password,
        )

    def get_dsn(self) -> str:
        """Get DSN connection string.

        Returns:
            str: DSN string

        For wallet connections (TNS_ADMIN set):
            Returns service_name directly (resolved via tnsnames.ora)

        For standard connections:
            Returns host:port/service_name format
        """
        if self.dsn:
            return self.dsn

        # If wallet is configured, use service name directly (tnsnames.ora resolves it)
        if self.wallet_location:
            return self.service_name or ""

        # Standard DSN format
        return f"{self.host}:{self.port}/{self.service_name}"


@dataclass
class ConnectionTestResult:
    """Result of connection test."""

    success: bool
    mode: DeploymentMode
    message: str
    connection_time_ms: float | None = None
    server_version: str | None = None
    user_info: dict[str, Any] | None = None
    error: str | None = None
    suggestions: list[str] | None = None


@dataclass
class ConnectionInfo:
    """Detailed connection information."""

    mode: DeploymentMode
    host: str
    port: int
    service_name: str
    user: str
    dsn: str
    wallet_location: str | None = None
    database_url: str | None = None


class ConnectionTester:
    """Test database connections across all deployment modes."""

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

        Automatically detects and uses wallet if configured.
        If display=True, shows formatted results.
        """
        if config is None:
            config = ConnectionConfig.from_env()

        # Test connection (handles wallet automatically)
        result = ConnectionTester._do_connection_test(config)

        if display:
            self.display_test_result(result)

        return result

    @staticmethod
    def _do_connection_test(config: ConnectionConfig) -> ConnectionTestResult:
        """Test database connection with automatic wallet detection.

        Args:
            config: Connection configuration

        Returns:
            ConnectionTestResult: Test results
        """
        import time

        start_time = time.time()

        # Pre-flight checks for wallet (if configured)
        if config.wallet_location and not config.wallet_location.exists():
            return ConnectionTestResult(
                success=False,
                mode=config.mode,
                message=f"Wallet directory not found: {config.wallet_location}",
                error=f"Directory does not exist: {config.wallet_location}",
                suggestions=[
                    "Verify WALLET_LOCATION path",
                    "Extract wallet: python manage.py wallet extract <zip>",
                ],
            )

        try:
            import oracledb

            # Configure TNS_ADMIN for wallet connections
            original_tns = os.environ.get("TNS_ADMIN")
            if config.wallet_location:
                os.environ["TNS_ADMIN"] = str(config.wallet_location)

            try:
                dsn = config.get_dsn()
                conn_params = {
                    "user": config.user,
                    "password": config.password,
                    "dsn": dsn,
                }

                # Add wallet password if configured
                if config.wallet_password:
                    conn_params["wallet_password"] = config.wallet_password

                with oracledb.connect(**conn_params) as connection:
                    # Execute test query
                    with connection.cursor() as cursor:
                        cursor.execute("SELECT 'OK' FROM DUAL")
                        cursor.fetchone()

                    version = connection.version
                    connection_time_ms = (time.time() - start_time) * 1000

                    # Build descriptive message
                    mode_desc = "managed container" if config.mode == DeploymentMode.MANAGED else "external database"
                    wallet_desc = " (wallet)" if config.wallet_location else ""
                    message = f"Successfully connected to {mode_desc}{wallet_desc}: {dsn}"

                    return ConnectionTestResult(
                        success=True,
                        mode=config.mode,
                        message=message,
                        connection_time_ms=connection_time_ms,
                        server_version=version,
                    )
            finally:
                # Restore original TNS_ADMIN
                if original_tns:
                    os.environ["TNS_ADMIN"] = original_tns
                elif "TNS_ADMIN" in os.environ:
                    del os.environ["TNS_ADMIN"]

        except Exception as e:  # noqa: BLE001
            error_msg = str(e)
            suggestions = get_connection_suggestions(config.mode, error_msg, config.wallet_location is not None)

            return ConnectionTestResult(
                success=False,
                mode=config.mode,
                message=f"Connection failed: {error_msg}",
                error=error_msg,
                suggestions=suggestions,
            )

    @staticmethod
    def get_connection_info(
        config: ConnectionConfig | None = None,
    ) -> ConnectionInfo:
        """Get detailed connection information.

        Args:
            config: Connection configuration (reads from env if None)

        Returns:
            ConnectionInfo: Connection details

        Provides information for debugging and .env configuration.
        """
        if config is None:
            config = ConnectionConfig.from_env()

        return ConnectionInfo(
            mode=config.mode,
            host=config.host or "N/A",
            port=config.port or 0,
            service_name=config.service_name or "N/A",
            user=config.user,
            dsn=config.get_dsn(),
            wallet_location=str(config.wallet_location) if config.wallet_location else None,
            database_url=config.database_url,
        )

    def display_test_result(
        self,
        result: ConnectionTestResult,
    ) -> None:
        """Display connection test results with Rich formatting.

        Args:
            result: Test results

        Shows:
            - Success/failure status
            - Connection time
            - Server version
            - User information
            - Error details (if failed)
            - Troubleshooting suggestions
        """
        self.console.print()
        if result.success:
            self.console.print(f"[green]✓ {result.message}[/green]")
            if result.connection_time_ms:
                self.console.print(f"  Connection time: {result.connection_time_ms:.2f}ms")
            if result.server_version:
                self.console.print(f"  Server version: {result.server_version}")
        else:
            self.console.print(f"[red]✗ {result.message}[/red]")
            if result.suggestions:
                self.console.print("\n[yellow]Suggestions:[/yellow]")
                for suggestion in result.suggestions:
                    self.console.print(f"  • {suggestion}")
        self.console.print()

    def display_connection_info(
        self,
        info: ConnectionInfo,
    ) -> None:
        """Display connection information with Rich formatting.

        Args:
            info: Connection information

        Shows formatted table with all connection details.
        """
        table = Table(title="Connection Information")
        table.add_column("Property", style="cyan")
        table.add_column("Value", style="white")

        table.add_row("Mode", info.mode.value)
        table.add_row("Host", info.host)
        table.add_row("Port", str(info.port))
        table.add_row("Service Name", info.service_name)
        table.add_row("User", info.user)
        table.add_row("DSN", info.dsn)

        if info.wallet_location:
            table.add_row("Wallet Location", info.wallet_location)
        if info.database_url:
            table.add_row("Database URL", info.database_url)

        self.console.print(table)

    @staticmethod
    def validate_credentials(
        config: ConnectionConfig,
    ) -> bool:
        """Quick validation of credentials without full connection.

        Args:
            config: Connection configuration

        Returns:
            bool: True if credentials are likely valid

        Checks:
            - Required fields are present
            - Password is not empty
            - Wallet files exist (if wallet configured)
        """
        # Check basic fields
        if not config.user or not config.password:
            return False

        # Check for wallet files if wallet is configured
        if config.wallet_location:
            if not config.wallet_location.exists():
                return False
            # Check for required wallet files
            required_files = ["cwallet.sso", "tnsnames.ora", "sqlnet.ora"]
            for file in required_files:
                if not (config.wallet_location / file).exists():
                    return False

        # For non-wallet connections, check standard fields
        return not (not config.wallet_location and (not config.host or not config.port or not config.service_name))

    @staticmethod
    def _connect(config: ConnectionConfig) -> Any:
        """Internal method to establish connection.

        Args:
            config: Connection configuration

        Returns:
            Connection object

        Uses oracledb async driver if available,
        falls back to sync driver.
        """
        import oracledb

        dsn = config.get_dsn()
        return oracledb.connect(user=config.user, password=config.password, dsn=dsn)

    @staticmethod
    def _execute_test_query(connection: Any) -> str:
        """Execute simple test query.

        Args:
            connection: Database connection

        Returns:
            str: Query result

        Executes: SELECT 'OK' FROM DUAL
        """
        with connection.cursor() as cursor:
            cursor.execute("SELECT 'OK' FROM DUAL")
            result = cursor.fetchone()
            return str(result[0]) if result else ""

    @staticmethod
    def _get_server_version(connection: Any) -> str:
        """Get Oracle server version.

        Args:
            connection: Database connection

        Returns:
            str: Server version string
        """
        return str(connection.version)

    @staticmethod
    def _get_user_info(connection: Any) -> dict[str, Any]:
        """Get current user information.

        Args:
            connection: Database connection

        Returns:
            dict: User details including:
                - username
                - default_tablespace
                - temp_tablespace
                - account_status
        """
        with connection.cursor() as cursor:
            cursor.execute("SELECT USER FROM DUAL")
            result = cursor.fetchone()
            return {"username": result[0] if result else "unknown"}


class OracleConnectionError(Exception):
    """Base exception for connection errors."""


class LocalConnectionError(OracleConnectionError):
    """Raised when local connection fails."""


class RemoteConnectionError(OracleConnectionError):
    """Raised when remote connection fails."""


class AutonomousConnectionError(OracleConnectionError):
    """Raised when autonomous connection fails."""


def detect_deployment_mode() -> DeploymentMode:
    """Auto-detect deployment mode from environment.

    Returns:
        DeploymentMode: Detected mode

    Detection logic:
        - If DATABASE_HOST is set -> EXTERNAL (connecting to existing DB)
        - If DATABASE_URL is set -> EXTERNAL (connecting to existing DB)
        - Default -> MANAGED (we control a Docker container)

    Wallet detection is automatic - if TNS_ADMIN/WALLET_LOCATION is set,
    we'll use wallet-based connection regardless of mode.
    """
    # Check if connecting to external database
    if os.getenv("DATABASE_HOST") or os.getenv("DATABASE_URL"):
        return DeploymentMode.EXTERNAL

    # Default to managed (Docker container)
    return DeploymentMode.MANAGED


def get_connection_suggestions(
    mode: DeploymentMode,
    error: str,
    has_wallet: bool = False,
) -> list[str]:
    """Get troubleshooting suggestions for connection failures.

    Args:
        mode: Deployment mode
        error: Error message
        has_wallet: Whether wallet is configured

    Returns:
        list[str]: Suggested actions
    """
    suggestions = []
    error_lower = error.lower()

    # Wallet-specific suggestions (applies to any mode with wallet)
    if has_wallet:
        if "wallet" in error_lower:
            suggestions.extend([
                "Verify WALLET_LOCATION points to valid wallet directory",
                "Check TNS_ADMIN is set correctly",
            ])
        if "password" in error_lower:
            suggestions.append("Verify WALLET_PASSWORD is correct")
        if "tns" in error_lower or "service" in error_lower:
            suggestions.extend([
                "Verify DATABASE_SERVICE_NAME matches a service in tnsnames.ora",
                "Check wallet files: cwallet.sso, tnsnames.ora, sqlnet.ora",
            ])

    # Mode-specific suggestions
    if mode == DeploymentMode.MANAGED:
        suggestions.extend([
            "Check if Oracle container is running: docker ps",
            "Start container: python manage.py database start",
        ])
        if "refused" in error_lower or "cannot connect" in error_lower:
            suggestions.append("Verify port mapping (default: 1521)")
        if "invalid username" in error_lower or "invalid password" in error_lower:
            suggestions.append("Check DATABASE_USER and DATABASE_PASSWORD environment variables")

    elif mode == DeploymentMode.EXTERNAL:
        if "refused" in error_lower or "cannot connect" in error_lower:
            suggestions.extend([
                "Verify host and port are correct",
                "Check firewall rules",
                "Ensure database listener is running",
                "Test network connectivity: ping <host>",
            ])
        if "invalid username" in error_lower or "invalid password" in error_lower:
            suggestions.append("Verify DATABASE_USER and DATABASE_PASSWORD")

    return suggestions
