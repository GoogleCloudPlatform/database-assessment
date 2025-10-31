"""CLI commands for MySQL connection testing."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

from tools.mysql.connection import ConnectionConfig, ConnectionTester

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="connect")
def connect_group() -> None:
    """Test and manage MySQL database connections."""


@connect_group.command(name="test")
@click.option("--timeout", default=10, help="Connection timeout in seconds")
def test_connection(timeout: int) -> None:
    """Test database connection."""
    try:
        tester = ConnectionTester(console=console)
        config = ConnectionConfig.from_env()

        console.print("[cyan]Testing connection...[/cyan]")
        result = tester.test(config, timeout=timeout, display=True)
        _exit_on_failure(result.success)
    except Exception as e:
        console.print(f"[red]Connection test failed: {e}[/red]")
        raise click.Abort from e


@connect_group.command(name="info")
def connection_info() -> None:
    """Display connection information."""
    try:
        tester = ConnectionTester(console=console)
        info = ConnectionTester.get_connection_info()
        tester.display_connection_info(info)
    except Exception as e:
        console.print(f"[red]Failed to get connection info: {e}[/red]")
        raise click.Abort from e
