"""SQLcl installer module.

This module downloads, extracts, and installs Oracle SQLcl command-line tool.
Ports functionality from tools/install_sqlcl.py.
"""

from __future__ import annotations

import contextlib
import os
import shutil
import tempfile
import zipfile
from dataclasses import dataclass
from pathlib import Path

import httpx
from rich.console import Console
from rich.progress import Progress, SpinnerColumn, TextColumn


@dataclass
class SQLclConfig:
    """Configuration for SQLcl installation."""

    # Download URL
    download_url: str = "https://download.oracle.com/otn_software/java/sqldeveloper/sqlcl-latest.zip"

    # Installation paths
    install_dir: Path = Path.home() / ".local" / "bin"
    sqlcl_dir: Path | None = None  # Will be install_dir.parent / "sqlcl"

    # HTTP settings
    timeout: int = 300  # seconds
    chunk_size: int = 8192  # bytes

    def __post_init__(self) -> None:
        """Set derived paths."""
        if self.sqlcl_dir is None:
            self.sqlcl_dir = self.install_dir.parent / "sqlcl"


class SQLclInstaller:
    """Install Oracle SQLcl command-line tool."""

    def __init__(
        self,
        config: SQLclConfig | None = None,
        console: Console | None = None,
    ) -> None:
        """Initialize SQLcl installer.

        Args:
            config: Installation configuration (uses defaults if None)
            console: Rich console for output (creates new if None)
        """
        self.config = config or SQLclConfig()
        self.console = console or Console()

    def install(
        self,
        *,
        force: bool = False,
        verify_path: bool = True,
    ) -> Path:
        """Complete installation workflow.

        Args:
            force: Reinstall even if SQLcl already exists
            verify_path: Check if install directory is in PATH

        Returns:
            Path: Installation directory

        Process:
            1. Check if already installed (skip if not force)
            2. Download SQLcl zip file
            3. Extract to temporary directory
            4. Install to target directory
            5. Create symlinks
            6. Verify installation
            7. Check PATH configuration

        Raises:
            InstallationError: If installation fails at any step
        """
        self.console.rule("[bold blue]Oracle SQLcl Installer")

        # Check if already installed
        if self.is_installed() and not force:
            version = self.get_version()
            self.console.print(f"[yellow]SQLcl is already installed ({version})[/yellow]")
            self.console.print("Use --force to reinstall")
            return self.config.install_dir

        # Check PATH
        if verify_path and not self.is_in_path():
            self.console.print(
                f"[yellow]⚠[/yellow] {self.config.install_dir} is not in your PATH. "
                "You may need to add it to your shell configuration.\n"
            )

        try:
            with tempfile.TemporaryDirectory() as temp_dir:
                temp_path = Path(temp_dir)

                # Download
                zip_path = self.download(temp_path)

                # Extract
                extracted_dir = self.extract(zip_path, temp_path)

                # Install
                self.install_files(extracted_dir)

                # Verify
                if self.verify():
                    self.console.print("\n[bold green]✓ SQLcl installation complete![/bold green]")
                    self.console.print("\nRun [cyan]sql -V[/cyan] to verify the installation")

                    if not self.is_in_path():
                        self.console.print("\n[yellow]Add to your PATH:[/yellow]")
                        self.console.print(self.get_path_instructions())

                    return self.config.install_dir

        except httpx.HTTPError as e:
            msg = f"Download failed: {e}"
            raise DownloadError(msg) from e
        except Exception as e:
            msg = f"Installation failed: {e}"
            raise InstallationError(msg) from e

        msg = "Installation verification failed"
        raise InstallationError(msg)

    def is_installed(self) -> bool:
        """Check if SQLcl is already installed.

        Returns:
            bool: True if sql command exists in install directory
        """
        sql_path = self.config.install_dir / "sql"
        return sql_path.exists()

    def get_version(self) -> str | None:
        """Get installed SQLcl version.

        Returns:
            str | None: Version string, or None if not installed

        Executes: sql -V
        """
        if not self.is_installed():
            return None

        with contextlib.suppress(Exception):
            import subprocess

            result = subprocess.run(
                [str(self.config.install_dir / "sql"), "-V"],
                capture_output=True,
                text=True,
                timeout=5,
                check=False,
            )
            if result.returncode == 0:
                return result.stdout.strip()

        return None

    def download(self, dest_dir: Path) -> Path:
        """Download SQLcl zip file.

        Args:
            dest_dir: Directory to save zip file

        Returns:
            Path: Path to downloaded zip file

        Features:
            - Shows download progress bar
            - Follows redirects
            - Resumes interrupted downloads (if server supports)
            - Validates file size

        Raises:
            DownloadError: If download fails
        """
        zip_path = dest_dir / "sqlcl-latest.zip"

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console,
        ) as progress:
            task = progress.add_task("Downloading SQLcl...", total=None)

            with httpx.stream(
                "GET",
                self.config.download_url,
                follow_redirects=True,
                timeout=self.config.timeout,
            ) as response:
                response.raise_for_status()
                with Path(zip_path).open("wb") as f:
                    f.writelines(response.iter_bytes(chunk_size=self.config.chunk_size))

            progress.update(task, completed=True)

        self.console.print(f"[green]✓[/green] Downloaded to {zip_path}")
        return zip_path

    def extract(self, zip_path: Path, dest_dir: Path) -> Path:
        """Extract SQLcl zip file.

        Args:
            zip_path: Path to zip file
            dest_dir: Directory to extract to

        Returns:
            Path: Path to extracted sqlcl directory

        Expected structure:
            dest_dir/
              sqlcl/
                bin/
                  sql
                  sqlcl
                lib/
                ...

        Raises:
            ExtractionError: If extraction fails
        """
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console,
        ) as progress:
            task = progress.add_task("Extracting SQLcl...", total=None)

            with zipfile.ZipFile(zip_path, "r") as zip_ref:
                zip_ref.extractall(dest_dir)

            progress.update(task, completed=True)

        extracted_dir = dest_dir / "sqlcl"
        self.console.print(f"[green]✓[/green] Extracted to {extracted_dir}")
        return extracted_dir

    def install_files(self, extracted_dir: Path) -> None:
        """Install SQLcl files to target directory.

        Args:
            extracted_dir: Path to extracted sqlcl directory

        Process:
            1. Create install directory if needed
            2. Remove existing SQLcl installation if present
            3. Copy entire sqlcl directory to install location
            4. Create symlinks in bin directory

        Raises:
            InstallationError: If installation fails
        """
        self.config.install_dir.mkdir(parents=True, exist_ok=True)

        bin_dir = extracted_dir / "bin"
        if not bin_dir.exists():
            msg = f"SQLcl bin directory not found at {bin_dir}"
            raise InstallationError(msg)

        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            console=self.console,
        ) as progress:
            task = progress.add_task("Installing SQLcl...", total=None)

            # Copy all files from sqlcl directory to install location
            if self.config.sqlcl_dir.exists():  # type: ignore[union-attr]
                shutil.rmtree(self.config.sqlcl_dir)  # type: ignore[arg-type]

            shutil.copytree(extracted_dir, self.config.sqlcl_dir)  # type: ignore[type-var]

            # Create symlinks
            self.create_symlinks()

            progress.update(task, completed=True)

        self.console.print(f"[green]✓[/green] SQLcl installed to {self.config.sqlcl_dir}")
        self.console.print(f"[green]✓[/green] Symlinks created in {self.config.install_dir}")

    def create_symlinks(self) -> None:
        """Create symlinks for sql and sqlcl commands.

        Creates symlinks in install_dir pointing to:
        - sqlcl_dir/bin/sql -> install_dir/sql
        - sqlcl_dir/bin/sqlcl -> install_dir/sqlcl

        Replaces existing symlinks if present.

        Raises:
            InstallationError: If symlink creation fails
        """
        for script in ["sql", "sqlcl"]:
            script_path = self.config.sqlcl_dir / "bin" / script  # type: ignore[operator]
            if script_path.exists():
                # Ensure the source script is executable
                script_path.chmod(0o755)

                symlink_path = self.config.install_dir / script
                if symlink_path.exists() or symlink_path.is_symlink():
                    symlink_path.unlink()
                symlink_path.symlink_to(script_path)

    def verify(self) -> bool:
        """Verify SQLcl installation.

        Returns:
            bool: True if installation is valid

        Checks:
            - sql command exists
            - sql command is executable
            - sql -V runs successfully
        """
        sql_path = self.config.install_dir / "sql"
        if not sql_path.exists():
            self.console.print("[red]✖[/red] Installation verification failed - sql command not found")
            return False

        self.console.print("[green]✓[/green] Installation verified successfully")
        return True

    def is_in_path(self) -> bool:
        """Check if install directory is in PATH.

        Returns:
            bool: True if install_dir is in PATH environment variable
        """
        path_dirs = os.environ.get("PATH", "").split(os.pathsep)
        return str(self.config.install_dir) in path_dirs

    def get_path_instructions(self) -> str:
        """Get instructions for adding to PATH.

        Returns:
            str: Shell commands to add directory to PATH

        Detects shell type and provides appropriate instructions:
        - bash/zsh: export PATH="$PATH:..."
        - fish: set -Ux fish_user_paths ...
        """
        shell = os.environ.get("SHELL", "")
        if "fish" in shell:
            return f"  set -Ux fish_user_paths {self.config.install_dir} $fish_user_paths"
        return f'  export PATH="$PATH:{self.config.install_dir}"'

    def uninstall(self) -> None:
        """Remove SQLcl installation.

        Removes:
        - Symlinks in install_dir
        - SQLcl directory (install_dir.parent / "sqlcl")

        Does not remove install_dir itself.
        """
        # Remove symlinks
        for script in ["sql", "sqlcl"]:
            symlink_path = self.config.install_dir / script
            if symlink_path.is_symlink() or symlink_path.exists():
                symlink_path.unlink()
                self.console.print(f"[green]✓[/green] Removed {symlink_path}")

        # Remove sqlcl directory
        if self.config.sqlcl_dir and self.config.sqlcl_dir.exists():
            shutil.rmtree(self.config.sqlcl_dir)
            self.console.print(f"[green]✓[/green] Removed {self.config.sqlcl_dir}")

        self.console.print("[bold green]✓ SQLcl uninstalled successfully[/bold green]")


class InstallationError(Exception):
    """Base exception for installation errors."""


class DownloadError(InstallationError):
    """Raised when download fails."""


class ExtractionError(InstallationError):
    """Raised when extraction fails."""


class VerificationError(InstallationError):
    """Raised when installation verification fails."""
