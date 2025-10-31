"""CLI commands for SQL Server health checking."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

from tools.sqlserver.health import HealthChecker

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.Abort


@click.command(name="health")
@click.option("--verbose", "-v", is_flag=True, help="Show detailed health information")
def health_command(verbose: bool) -> None:
    """Check health of SQL Server deployment."""
    try:
        checker = HealthChecker(console=console)
        health = checker.check_all(verbose=verbose)
        checker.display_health(health, verbose=verbose)
        _exit_on_failure(health.is_healthy)
    except Exception as e:
        console.print(f"[red]Health check failed: {e}[/red]")
        raise click.Abort from e
