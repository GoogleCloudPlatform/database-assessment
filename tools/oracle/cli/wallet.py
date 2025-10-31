"""Wallet configuration and management CLI commands."""

from __future__ import annotations

from pathlib import Path

import rich_click as click
from rich.console import Console

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="wallet")
def wallet_group() -> None:
    """Manage Autonomous Database wallets.

    Extract, configure, and validate Oracle Autonomous Database wallet files.
    """


@wallet_group.command(name="extract")
@click.argument("wallet_zip", type=click.Path(exists=True))
@click.option("--dest", type=click.Path(), help="Destination directory (default: .envs/tns)")
def wallet_extract(wallet_zip: str, dest: str | None) -> None:
    """Extract wallet zip file.

    Extracts Wallet_*.zip file to specified directory.
    """
    from tools.oracle.wallet import WalletConfigurator

    configurator = WalletConfigurator()
    zip_path = Path(wallet_zip)
    dest_dir = Path(dest) if dest else None

    try:
        extracted_dir = configurator.extract_wallet(zip_path, dest_dir)
        console.print(f"[green]✓ Wallet extracted to: {extracted_dir}[/green]")
    except Exception as e:
        console.print(f"[red]✗ Failed to extract wallet: {e}[/red]")
        _exit_on_failure(False)


@wallet_group.command(name="configure")
@click.option("--wallet-dir", type=click.Path(exists=True), help="Wallet directory")
@click.option("--non-interactive", is_flag=True, help="Skip interactive prompts")
def wallet_configure(wallet_dir: str | None, non_interactive: bool) -> None:
    """Interactive wallet configuration wizard.

    Guides through wallet setup and generates .env configuration.
    Replaces: app database configure
    """
    from tools.oracle.wallet import WalletConfigurator

    configurator = WalletConfigurator()
    wallet_path = Path(wallet_dir) if wallet_dir else None

    try:
        wallet_info = configurator.configure(wallet_path=wallet_path, interactive=not non_interactive)
        if wallet_info.is_valid:
            console.print("[green]✓ Wallet configuration complete![/green]")
    except Exception as e:
        console.print(f"[red]✗ Configuration failed: {e}[/red]")
        _exit_on_failure(False)


@wallet_group.command(name="list-services")
@click.option("--wallet-dir", type=click.Path(exists=True), help="Wallet directory")
def wallet_list_services(wallet_dir: str | None) -> None:
    """List available database services in wallet.

    Shows all service names from tnsnames.ora.
    """
    from tools.oracle.wallet import WalletConfigurator

    configurator = WalletConfigurator()

    # Find wallet if not provided
    if wallet_dir:
        wallet_path = Path(wallet_dir)
    else:
        found = configurator.find_wallet()
        if not found:
            console.print("[yellow]⚠ No wallet found. Please specify --wallet-dir[/yellow]")
            _exit_on_failure(False)
        wallet_path = found if found.is_dir() else configurator.extract_wallet(found)

    try:
        services = configurator.list_services(wallet_path, display=True)
        if not services:
            console.print("[yellow]No services found in wallet[/yellow]")
    except Exception as e:
        console.print(f"[red]✗ Failed to list services: {e}[/red]")
        _exit_on_failure(False)


@wallet_group.command(name="validate")
@click.option("--wallet-dir", type=click.Path(exists=True), help="Wallet directory")
def wallet_validate(wallet_dir: str | None) -> None:
    """Validate wallet files.

    Checks for required files and verifies wallet integrity.
    """
    from tools.oracle.wallet import WalletConfigurator

    configurator = WalletConfigurator()

    # Find wallet if not provided
    if wallet_dir:
        wallet_path = Path(wallet_dir)
    else:
        found = configurator.find_wallet()
        if not found:
            console.print("[yellow]⚠ No wallet found. Please specify --wallet-dir[/yellow]")
            _exit_on_failure(False)
        wallet_path = found if found.is_dir() else configurator.extract_wallet(found)

    try:
        wallet_info = configurator.validate_wallet(wallet_path)

        if wallet_info.is_valid:
            console.print("[green]✓ Wallet is valid[/green]")
            console.print(f"\nWallet location: {wallet_info.wallet_dir}")
            console.print(f"Required files present: {wallet_info.required_files_present}")
            if wallet_info.services:
                console.print(f"Services found: {len(wallet_info.services)}")
        else:
            console.print("[red]✗ Wallet validation failed[/red]")
            for error in wallet_info.validation_errors or []:
                console.print(f"  • {error}")
            _exit_on_failure(False)
    except Exception as e:
        console.print(f"[red]✗ Validation failed: {e}[/red]")
        _exit_on_failure(False)
