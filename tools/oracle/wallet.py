"""Wallet configurator for Oracle Autonomous Database.

This module handles wallet extraction, validation, and configuration
for Oracle Autonomous Database connections.
"""

from __future__ import annotations

import os
import zipfile
from dataclasses import dataclass
from pathlib import Path

from rich.console import Console
from rich.prompt import Confirm


@dataclass
class WalletInfo:
    """Information about an Oracle wallet."""

    # Paths
    wallet_dir: Path
    zip_path: Path | None = None

    # Files
    has_cwallet: bool = False
    has_ewallet: bool = False
    has_tnsnames: bool = False
    has_sqlnet: bool = False
    has_keystore: bool = False
    has_truststore: bool = False

    # Services
    services: list[str] | None = None

    # Validation
    is_valid: bool = False
    validation_errors: list[str] | None = None

    @property
    def required_files_present(self) -> bool:
        """Check if all required files are present."""
        return self.has_cwallet and self.has_tnsnames and self.has_sqlnet


@dataclass
class WalletConfig:
    """Configuration for wallet operations."""

    # Default wallet locations to check
    default_locations: list[Path] | None = None

    # Required wallet files
    required_files: list[str] | None = None

    # Optional wallet files
    optional_files: list[str] | None = None

    def __post_init__(self) -> None:
        """Set default values."""
        if self.default_locations is None:
            self.default_locations = [
                Path(".envs/tns"),
                Path(os.getenv("WALLET_LOCATION", "")),
                Path(os.getenv("TNS_ADMIN", "")),
                Path.home() / ".oracle" / "wallet",
            ]

        if self.required_files is None:
            self.required_files = [
                "cwallet.sso",
                "tnsnames.ora",
                "sqlnet.ora",
            ]

        if self.optional_files is None:
            self.optional_files = [
                "ewallet.p12",
                "keystore.jks",
                "truststore.jks",
                "ojdbc.properties",
            ]


class WalletConfigurator:
    """Configure and validate Oracle Autonomous Database wallets."""

    def __init__(
        self,
        config: WalletConfig | None = None,
        console: Console | None = None,
    ) -> None:
        """Initialize wallet configurator.

        Args:
            config: Wallet configuration (uses defaults if None)
            console: Rich console for output (creates new if None)
        """
        self.config = config or WalletConfig()
        self.console = console or Console()

    def configure(
        self,
        wallet_path: Path | None = None,
        *,
        interactive: bool = True,
    ) -> WalletInfo:
        """Interactive wallet configuration wizard.

        Args:
            wallet_path: Path to wallet directory or zip file (auto-detect if None)
            interactive: Use interactive prompts

        Returns:
            WalletInfo: Information about configured wallet

        Process:
            1. Locate wallet (provided, auto-detect, or prompt)
            2. Extract if zip file
            3. Validate wallet contents
            4. Parse tnsnames.ora
            5. Display available services
            6. Prompt for service selection (if interactive)
            7. Generate .env configuration snippet
            8. Set TNS_ADMIN if requested

        This ports logic from app/cli/commands.py:configure_database()

        Raises:
            WalletNotFoundError: If wallet cannot be located
            WalletValidationError: If wallet is invalid
        """
        self.console.rule("[bold blue]Oracle Autonomous Database Configuration", style="blue", align="left")
        self.console.print()

        # Step 1: Locate wallet
        self.console.print("[yellow]🔍 Checking for Oracle wallet...[/yellow]")

        found_wallet = wallet_path or self.find_wallet()
        if not found_wallet:
            self.console.print("[yellow]⚠ No wallet found[/yellow]")
            self.console.print("\n[dim]For Autonomous Database, set:[/dim]")
            self.console.print("  WALLET_LOCATION=/path/to/wallet")
            self.console.print("  DATABASE_SERVICE_NAME=<service_name>_high")
            self.console.print("\n[dim]For local Oracle, set:[/dim]")
            self.console.print("  DATABASE_HOST=localhost")
            self.console.print("  DATABASE_PORT=1521")
            self.console.print("  DATABASE_SERVICE_NAME=FREEPDB1")
            msg = "No wallet found. Please specify wallet location."
            raise WalletNotFoundError(msg)

        self.console.print(f"[green]✓ Wallet found: {found_wallet}[/green]")

        # Step 2: Extract if zip file
        wallet_dir = found_wallet
        zip_path = None
        if found_wallet.is_file() and found_wallet.suffix == ".zip":
            zip_path = found_wallet
            wallet_dir = self.extract_wallet(zip_path)

        # Step 3: Validate wallet
        wallet_info = self.validate_wallet(wallet_dir)
        wallet_info.zip_path = zip_path

        if not wallet_info.is_valid:
            self.console.print("[red]✗ Wallet validation failed:[/red]")
            for error in wallet_info.validation_errors or []:
                self.console.print(f"  • {error}")
            msg = f"Invalid wallet: {wallet_info.validation_errors}"
            raise WalletValidationError(msg)

        # Step 4: Display tnsnames.ora status
        if wallet_info.has_tnsnames:
            self.console.print("[green]✓ tnsnames.ora found[/green]")

            # Step 5: Display available services
            if wallet_info.services:
                self.list_services(wallet_dir, display=True)

        # Step 6: Generate environment configuration
        env_vars = WalletConfigurator.get_env_config(wallet_dir)

        # Step 7: Display configuration help
        self.display_configuration_help(wallet_info, env_vars)

        # Step 8: Set TNS_ADMIN if requested
        if interactive:
            set_env = Confirm.ask("Set TNS_ADMIN for current session?", default=True)
            if set_env:
                self.set_tns_admin(wallet_dir)

        return wallet_info

    def find_wallet(
        self,
        start_path: Path | None = None,
    ) -> Path | None:
        """Search for wallet directory or zip file.

        Args:
            start_path: Starting directory (uses defaults if None)

        Returns:
            Path | None: Path to wallet directory or zip file

        Search order:
            1. start_path if provided
            2. WALLET_LOCATION environment variable
            3. TNS_ADMIN environment variable
            4. .envs/tns directory
            5. ~/.oracle/wallet directory

        Looks for:
            - Directories containing cwallet.sso
            - Wallet_*.zip files
        """
        # If start_path provided, check it first
        if start_path and start_path.exists():
            if start_path.is_file() and start_path.suffix == ".zip":
                return start_path
            if start_path.is_dir() and (start_path / "cwallet.sso").exists():
                return start_path

        # Check all default locations
        for location in self.config.default_locations or []:
            if not location or not location.exists():
                continue

            # Check if it's a wallet directory
            if location.is_dir():
                if (location / "cwallet.sso").exists():
                    return location
                # Check for wallet zip files in directory
                for zip_file in location.glob("Wallet_*.zip"):
                    return zip_file

            # Check if it's a wallet zip file
            if location.is_file() and location.suffix == ".zip":
                return location

        return None

    def extract_wallet(
        self,
        zip_path: Path,
        dest_dir: Path | None = None,
    ) -> Path:
        """Extract wallet zip file.

        Args:
            zip_path: Path to wallet zip file
            dest_dir: Destination directory (creates temp if None)

        Returns:
            Path: Path to extracted wallet directory

        Extracts:
            - Wallet_*.zip -> dest_dir/
            - All files to root of dest_dir

        Raises:
            WalletExtractionError: If extraction fails
        """
        if not zip_path.exists():
            msg = f"Wallet zip file not found: {zip_path}"
            raise WalletExtractionError(msg)

        # Use same directory as zip file if dest_dir not provided
        if dest_dir is None:
            # Extract to same directory, using wallet name
            wallet_name = zip_path.stem  # "Wallet_DBNAME" from "Wallet_DBNAME.zip"
            dest_dir = zip_path.parent / wallet_name

        # Create destination directory
        dest_dir.mkdir(parents=True, exist_ok=True)

        try:
            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(dest_dir)
        except Exception as e:
            msg = f"Failed to extract wallet: {e}"
            raise WalletExtractionError(msg) from e
        else:
            self.console.print(f"[green]✓ Extracted wallet to {dest_dir}[/green]")
            return dest_dir

    def validate_wallet(self, wallet_dir: Path) -> WalletInfo:
        """Validate wallet directory contents.

        Args:
            wallet_dir: Path to wallet directory

        Returns:
            WalletInfo: Validation results and wallet information

        Checks:
            - Required files present
            - Files are readable
            - tnsnames.ora is parseable
            - sqlnet.ora contains WALLET_LOCATION placeholder
        """
        errors: list[str] = []

        # Check directory exists
        if not wallet_dir.exists():
            errors.append(f"Wallet directory not found: {wallet_dir}")
            return WalletInfo(
                wallet_dir=wallet_dir,
                is_valid=False,
                validation_errors=errors,
            )

        # Check for required files
        has_cwallet = (wallet_dir / "cwallet.sso").exists()
        has_ewallet = (wallet_dir / "ewallet.p12").exists()
        has_tnsnames = (wallet_dir / "tnsnames.ora").exists()
        has_sqlnet = (wallet_dir / "sqlnet.ora").exists()
        has_keystore = (wallet_dir / "keystore.jks").exists()
        has_truststore = (wallet_dir / "truststore.jks").exists()

        # Validate required files
        for required_file in self.config.required_files or []:
            file_path = wallet_dir / required_file
            if not file_path.exists():
                errors.append(f"Missing required file: {required_file}")

        # Try to parse services
        services: list[str] = []
        if has_tnsnames:
            try:
                services = WalletConfigurator.parse_tnsnames(wallet_dir)
            except TNSParseError as e:
                errors.append(f"Failed to parse tnsnames.ora: {e}")

        # Create wallet info
        return WalletInfo(
            wallet_dir=wallet_dir,
            has_cwallet=has_cwallet,
            has_ewallet=has_ewallet,
            has_tnsnames=has_tnsnames,
            has_sqlnet=has_sqlnet,
            has_keystore=has_keystore,
            has_truststore=has_truststore,
            services=services,
            is_valid=len(errors) == 0,
            validation_errors=errors or None,
        )

    @staticmethod
    def parse_tnsnames(wallet_dir: Path) -> list[str]:
        """Parse tnsnames.ora for service names.

        Args:
            wallet_dir: Path to wallet directory

        Returns:
            list[str]: Available service names

        Extracts service names from lines like:
            service_name_high = (DESCRIPTION=...)
            service_name_low = (DESCRIPTION=...)

        Raises:
            TNSParseError: If tnsnames.ora cannot be parsed
        """
        tnsnames_path = wallet_dir / "tnsnames.ora"
        if not tnsnames_path.exists():
            msg = f"tnsnames.ora not found in {wallet_dir}"
            raise TNSParseError(msg)

        try:
            with tnsnames_path.open() as f:
                content = f.read()

            # Parse service names (simple parsing matching app/cli/commands.py logic)
            return [
                line.split("=")[0].strip()
                for line in content.split("\n")
                if "=" in line and not line.strip().startswith("#") and line.split("=")[0].strip()
            ]

        except Exception as e:
            msg = f"Failed to parse tnsnames.ora: {e}"
            raise TNSParseError(msg) from e

    def list_services(
        self,
        wallet_dir: Path,
        *,
        display: bool = True,
    ) -> list[str]:
        """List available database services in wallet.

        Args:
            wallet_dir: Path to wallet directory
            display: Print formatted list to console

        Returns:
            list[str]: Service names

        If display=True, shows Rich formatted table with:
            - Service name
            - Connection priority (high, medium, low)
            - Description
        """
        services = WalletConfigurator.parse_tnsnames(wallet_dir)

        if display and services:
            self.console.print("\n[bold]Available database services:[/bold]")
            for i, service in enumerate(services, 1):
                # Determine priority from service name suffix
                priority = "Unknown"
                if service.lower().endswith("_high"):
                    priority = "[green]High[/green]"
                elif service.lower().endswith("_medium"):
                    priority = "[yellow]Medium[/yellow]"
                elif service.lower().endswith("_low"):
                    priority = "[blue]Low[/blue]"
                elif service.lower().endswith("_tp"):
                    priority = "[cyan]TP (Transaction Processing)[/cyan]"
                elif service.lower().endswith("_tpurgent"):
                    priority = "[red]TP Urgent[/red]"

                self.console.print(f"  {i}. [bold]{service}[/bold] - {priority}")

        return services

    @staticmethod
    def get_env_config(
        wallet_dir: Path,
        service_name: str | None = None,
    ) -> dict[str, str]:
        """Generate environment variable configuration.

        Args:
            wallet_dir: Path to wallet directory
            service_name: Database service name (prompts if None)

        Returns:
            dict: Environment variables to set:
                - WALLET_LOCATION: Path to wallet
                - TNS_ADMIN: Path to wallet
                - DATABASE_SERVICE_NAME: Service name
                - (DATABASE_URL requires user input)

        Can be written to .env file or displayed to user.
        """
        env_vars = {
            "WALLET_LOCATION": str(wallet_dir.absolute()),
            "TNS_ADMIN": str(wallet_dir.absolute()),
        }

        if service_name:
            env_vars["DATABASE_SERVICE_NAME"] = service_name

        return env_vars

    def set_tns_admin(self, wallet_dir: Path) -> None:
        """Set TNS_ADMIN environment variable.

        Args:
            wallet_dir: Path to wallet directory

        Sets TNS_ADMIN for current process and provides
        instructions for permanent configuration.
        """
        wallet_path = str(wallet_dir.absolute())
        os.environ["TNS_ADMIN"] = wallet_path
        os.environ["WALLET_LOCATION"] = wallet_path
        self.console.print(f"[green]✓ Set TNS_ADMIN={wallet_path}[/green]")

    def display_configuration_help(
        self,
        wallet_info: WalletInfo,
        env_vars: dict[str, str],
    ) -> None:
        """Display configuration instructions to user.

        Args:
            wallet_info: Wallet information
            env_vars: Environment variables

        Displays Rich formatted output with:
            - Wallet location and status
            - Available services
            - Environment variables to set
            - .env file snippet
            - Shell export commands
            - Next steps
        """
        self.console.print()
        self.console.print("[dim]Configure these in your .env file:[/dim]")
        for key, value in env_vars.items():
            self.console.print(f"  {key}={value}")

        if wallet_info.services:
            self.console.print(f"  DATABASE_SERVICE_NAME=<your_service_name>  # e.g., {wallet_info.services[0]}")

        self.console.print("  DATABASE_USERNAME=<your_username>")
        self.console.print("  DATABASE_PASSWORD=<your_password>")
        self.console.print()

    def test_wallet(
        self,
        wallet_dir: Path,
        service_name: str,
        username: str,
        password: str,
    ) -> bool:
        """Test wallet connectivity.

        Args:
            wallet_dir: Path to wallet directory
            service_name: Database service name
            username: Database username
            password: Database password

        Returns:
            bool: True if connection successful

        Quick connection test using oracledb.
        """
        try:
            import oracledb

            # Set TNS_ADMIN temporarily
            original_tns = os.environ.get("TNS_ADMIN")
            os.environ["TNS_ADMIN"] = str(wallet_dir.absolute())

            try:
                with (
                    oracledb.connect(
                        user=username,
                        password=password,
                        dsn=service_name,
                    ) as connection,
                    connection.cursor() as cursor,
                ):
                    cursor.execute("SELECT 1 FROM DUAL")
                    cursor.fetchone()
                return True
            finally:
                # Restore original TNS_ADMIN
                if original_tns:
                    os.environ["TNS_ADMIN"] = original_tns
                elif "TNS_ADMIN" in os.environ:
                    del os.environ["TNS_ADMIN"]

        except Exception as e:  # noqa: BLE001
            self.console.print(f"[red]✗ Connection test failed: {e}[/red]")
            return False


class WalletError(Exception):
    """Base exception for wallet operations."""


class WalletNotFoundError(WalletError):
    """Raised when wallet cannot be located."""


class WalletValidationError(WalletError):
    """Raised when wallet validation fails."""


class WalletExtractionError(WalletError):
    """Raised when wallet extraction fails."""


class TNSParseError(WalletError):
    """Raised when tnsnames.ora parsing fails."""
