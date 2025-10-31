"""SQLcl installation and management CLI commands."""

from __future__ import annotations

from pathlib import Path

import rich_click as click
from rich.console import Console

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="sqlcl")
def sqlcl_group() -> None:
    """Manage SQLcl installation.

    Install, verify, and manage Oracle SQLcl command-line tool.
    """


@sqlcl_group.command(name="install")
@click.option("--dir", "install_dir", type=click.Path(), help="Installation directory")
@click.option("--force", is_flag=True, help="Reinstall even if already installed")
def sqlcl_install(install_dir: str | None, force: bool) -> None:
    """Install Oracle SQLcl.

    Downloads and installs the latest version of SQLcl to ~/.local/bin by default.
    """
    from tools.oracle.sqlcl_installer import SQLclConfig, SQLclInstaller

    try:
        config = SQLclConfig()
        if install_dir:
            config.install_dir = Path(install_dir)

        installer = SQLclInstaller(config=config, console=console)

        console.print("[yellow]Installing SQLcl...[/yellow]")
        installed_path = installer.install(force=force)

        console.print(f"[green]✓ SQLcl installed to: {installed_path}[/green]")

        # Check if in PATH
        if not installer.is_in_path():
            console.print("\n[yellow]⚠ SQLcl is not in your PATH[/yellow]")
            instructions = installer.get_path_instructions()
            for instruction in instructions:
                console.print(f"  {instruction}")

    except Exception as e:
        console.print(f"[red]✗ Installation failed: {e}[/red]")
        raise click.Abort from e


@sqlcl_group.command(name="verify")
def sqlcl_verify() -> None:
    """Verify SQLcl installation.

    Checks if SQLcl is installed and shows version information.
    """
    from tools.oracle.sqlcl_installer import SQLclInstaller

    try:
        installer = SQLclInstaller(console=console)

        if not installer.is_installed():
            console.print("[yellow]SQLcl is not installed[/yellow]")
            console.print("\nInstall with: uv run python tools/oracle_deploy.py sqlcl install")
            _exit_on_failure(False)

        version = installer.get_version()
        in_path = installer.is_in_path()

        console.print("\n[green]✓ SQLcl is installed[/green]")
        console.print(f"  Version: {version}")
        console.print(f"  In PATH: {'Yes' if in_path else 'No'}")

        if not in_path:
            console.print("\n[yellow]To add SQLcl to PATH:[/yellow]")
            instructions = installer.get_path_instructions()
            for instruction in instructions:
                console.print(f"  {instruction}")

        # Test if it works
        if installer.verify():
            console.print("\n[green]✓ SQLcl is working correctly[/green]")
        else:
            console.print("\n[red]✗ SQLcl verification failed[/red]")
            _exit_on_failure(False)

    except Exception as e:
        if not isinstance(e, click.Abort):
            console.print(f"[red]✗ Verification failed: {e}[/red]")
        raise click.Abort from e


@sqlcl_group.command(name="uninstall")
@click.confirmation_option(prompt="Are you sure you want to uninstall SQLcl?")
def sqlcl_uninstall() -> None:
    """Uninstall SQLcl."""
    from tools.oracle.sqlcl_installer import SQLclInstaller

    try:
        installer = SQLclInstaller(console=console)

        if not installer.is_installed():
            console.print("[yellow]SQLcl is not installed[/yellow]")
            return

        console.print("[yellow]Uninstalling SQLcl...[/yellow]")
        installer.uninstall()
        console.print("[green]✓ SQLcl uninstalled[/green]")

    except Exception as e:
        console.print(f"[red]✗ Uninstall failed: {e}[/red]")
        raise click.Abort from e
