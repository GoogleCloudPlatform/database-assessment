"""CLI commands for PostgreSQL connection testing."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

from tools.postgres.connection import ConnectionConfig, ConnectionTester

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="connect")
def connect_group() -> None:
    """Test and manage PostgreSQL database connections.

    Commands for testing connectivity to managed containers or external databases.
    """


@connect_group.command(name="test")
@click.option("--timeout", default=10, help="Connection timeout in seconds")
def test_connection(timeout: int) -> None:
    """Test database connection.

    Performs comprehensive connection test including:
    - Basic connectivity
    - Authentication
    - Query execution
    - Server version check
    - Extension availability (pgvector)

    Uses environment variables or defaults for managed container:
        DATABASE_USER=app
        DATABASE_PASSWORD=super-secret
        DATABASE_HOST=localhost
        DATABASE_PORT=15432
        DATABASE_NAME=app

    Examples:
        # Test managed container connection
        python manage.py database postgres connect test

        # Test with custom timeout
        python manage.py database postgres connect test --timeout 30
    """
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
    """Display connection information.

    Shows current connection configuration without testing the connection.
    Useful for debugging connection parameters.

    Examples:
        python manage.py database postgres connect info
    """
    try:
        tester = ConnectionTester(console=console)
        info = ConnectionTester.get_connection_info()
        tester.display_connection_info(info)

    except Exception as e:
        console.print(f"[red]Failed to get connection info: {e}[/red]")
        raise click.Abort from e
