"""System health check CLI commands."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.command(name="status")
@click.option("--verbose", "-v", is_flag=True, help="Show detailed diagnostics")
@click.option(
    "--mode",
    type=click.Choice(["managed", "external"]),
    help="Check specific deployment mode",
)
def status_command(verbose: bool, mode: str | None) -> None:
    """Check overall system health.

    Comprehensive health check of all deployment components:
    - Container runtime (Docker/Podman)
    - Database container (if managed mode)
    - SQLcl installation
    - Wallet configuration (if wallet configured)
    - Database connectivity
    """
    from tools.oracle.connection import DeploymentMode
    from tools.oracle.health import HealthChecker

    checker = HealthChecker(console=console)

    try:
        # Convert mode string to enum if provided
        deployment_mode = DeploymentMode(mode.upper()) if mode else None

        # Run health checks
        health = checker.check_all(deployment_mode=deployment_mode, verbose=verbose)

        # Display results
        checker.display_health(health, verbose=verbose)

        # Exit with error code if unhealthy
        _exit_on_failure(health.is_healthy)

    except Exception as e:
        if not isinstance(e, click.Abort):
            console.print(f"[red]✗ Health check failed: {e}[/red]")
        raise click.Abort from e
