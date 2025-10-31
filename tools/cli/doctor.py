"""Health check and diagnostics CLI command."""

from __future__ import annotations

import os
import shutil
from pathlib import Path

import rich_click as click
from rich.console import Console

from tools.lib.utils import check_env_file, detect_deployment_mode, run_command

console = Console()


@click.command(name="doctor")
@click.option(
    "--mode",
    type=click.Choice(["managed", "external"], case_sensitive=False),
    help="Check prerequisites for specific mode (auto-detect if not specified)",
)
@click.option(
    "--json",
    "json_output",
    is_flag=True,
    help="Output results as JSON",
)
@click.option(
    "--verbose",
    "-v",
    is_flag=True,
    help="Show detailed diagnostic information",
)
def doctor_command(mode: str | None, json_output: bool, verbose: bool) -> None:
    """Verify all prerequisites and configuration.

    Checks:
    - .env file exists and is valid
    - UV package manager installed
    - Mode-specific requirements (Docker for managed, wallet if configured)
    - Database connectivity (optional)

    Exit codes:
    - 0: All checks passed
    - 1: One or more checks failed
    """
    if mode is None:
        mode = detect_deployment_mode()

    if not json_output:
        console.rule(f"[bold blue]Health Check for '{mode}' Mode", style="blue")
        console.print()

    # Initialize checks dictionary
    checks = {"env_file": False, "uv_installed": False, "mode_specific": {}, "overall": False}

    # Check .env file
    if not json_output:
        console.print("[yellow]📄 Checking .env file...[/yellow]")
    checks["env_file"] = check_env_file()
    if not json_output:
        if checks["env_file"]:
            console.print("[green]✓ .env file exists[/green]")
        else:
            console.print("[red]✗ .env file not found[/red]")
            console.print("[dim]  Run: python manage.py init[/dim]")

    # Check UV
    if not json_output:
        console.print("[yellow]📦 Checking UV package manager...[/yellow]")
    uv_path = shutil.which("uv")
    checks["uv_installed"] = uv_path is not None
    if not json_output:
        if checks["uv_installed"]:
            returncode, stdout, _ = run_command(["uv", "--version"], check=False)
            version = stdout.strip() if returncode == 0 else "unknown"
            console.print(f"[green]✓ UV installed: {version}[/green]")
            if verbose:
                console.print(f"[dim]  Location: {uv_path}[/dim]")
        else:
            console.print("[red]✗ UV not found[/red]")
            console.print("[dim]  Run: python manage.py install uv[/dim]")

    # Mode-specific checks
    if not json_output:
        console.print(f"[yellow]🔧 Checking '{mode}' mode prerequisites...[/yellow]")

    mode_specific_checks: dict[str, bool] = {}
    if mode == "managed":
        has_docker = shutil.which("docker") is not None
        has_podman = shutil.which("podman") is not None
        mode_specific_checks["container_runtime"] = has_docker or has_podman
        if not json_output:
            if has_docker:
                console.print("[green]✓ Docker found[/green]")
            elif has_podman:
                console.print("[green]✓ Podman found[/green]")
            else:
                console.print("[red]✗ Neither Docker nor Podman found[/red]")
                console.print("[dim]  Install from: https://www.docker.com/get-started[/dim]")
    elif mode == "external":
        wallet_location = os.getenv("WALLET_LOCATION") or os.getenv("TNS_ADMIN")
        if wallet_location:
            mode_specific_checks["wallet_configured"] = True
            wallet_path = Path(wallet_location)
            mode_specific_checks["wallet_exists"] = wallet_path.exists()
            if wallet_path.exists():
                cwallet = wallet_path / "cwallet.sso"
                tnsnames = wallet_path / "tnsnames.ora"
                mode_specific_checks["wallet_valid"] = cwallet.exists() and tnsnames.exists()
            else:
                mode_specific_checks["wallet_valid"] = False
            if not json_output:
                console.print(f"[green]✓ Wallet location configured: {wallet_location}[/green]")
                if mode_specific_checks.get("wallet_exists"):
                    console.print("[green]✓ Wallet directory exists[/green]")
                    if mode_specific_checks.get("wallet_valid"):
                        console.print("[green]✓ Wallet files valid[/green]")
                    else:
                        console.print("[red]✗ Wallet missing required files[/red]")
                else:
                    console.print("[red]✗ Wallet directory not found[/red]")
        elif not json_output:
            console.print("[dim]i No wallet configured (using standard connection)[/dim]")
    checks["mode_specific"] = mode_specific_checks

    # Overall status
    checks["overall"] = all([
        checks["env_file"],
        checks["uv_installed"],
        all(mode_specific_checks.values()) if mode_specific_checks else True,
    ])

    # Output results
    if json_output:
        import json as json_module

        console.print(json_module.dumps(checks, indent=2))
    else:
        console.print()
        if checks["overall"]:
            console.print("[bold green]✓ All checks passed![/bold green]")
            console.print()
            console.print("[bold]Next steps:[/bold]")
            console.print("  • Run [cyan]python manage.py database connect[/cyan] to verify database connection")
            console.print("  • Run [cyan]uv run app run[/cyan] to start the application")
        else:
            console.print("[bold red]✗ Some checks failed[/bold red]")
            console.print()
            console.print("[bold]To fix:[/bold]")
            if not checks["env_file"]:
                console.print("  • Run [cyan]python manage.py init[/cyan]")
            if not checks["uv_installed"]:
                console.print("  • Run [cyan]python manage.py install uv[/cyan]")
            if not all(mode_specific_checks.values()):
                console.print("  • Check mode-specific requirements above")

    if not checks["overall"]:
        raise click.Abort
