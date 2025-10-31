"""Database connection testing CLI commands."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="connect")
def connect_group() -> None:
    """Test database connections.

    Test connectivity to Oracle databases in any deployment mode.
    """


@connect_group.command(name="test")
@click.option(
    "--mode",
    type=click.Choice(["managed", "external"]),
    help="Deployment mode (auto-detect if not specified)",
)
@click.option("--timeout", default=10, help="Connection timeout in seconds")
def connect_test(mode: str | None, timeout: int) -> None:
    """Test database connection.

    Attempts to connect and execute a simple query.
    Auto-detects wallet if configured.
    """
    from tools.oracle.connection import ConnectionConfig, ConnectionTester, DeploymentMode

    tester = ConnectionTester(console=console)

    try:
        # If mode specified, create config for that mode
        if mode:
            deployment_mode = DeploymentMode(mode.upper())
            config = ConnectionConfig.from_env()
            config.mode = deployment_mode
        else:
            # Auto-detect from environment
            config = ConnectionConfig.from_env()

        # Run connection test
        result = tester.test(config, timeout=timeout, display=True)

        _exit_on_failure(result.success)

    except Exception as e:
        if not isinstance(e, click.Abort):
            console.print(f"[red]✗ Test failed: {e}[/red]")
        raise click.Abort from e


@connect_group.command(name="info")
def connect_info() -> None:
    """Display connection information.

    Shows current connection configuration from environment.
    """
    from tools.oracle.connection import ConnectionTester

    tester = ConnectionTester(console=console)

    try:
        info = ConnectionTester.get_connection_info()
        tester.display_connection_info(info)
    except Exception as e:
        console.print(f"[red]✗ Failed to get connection info: {e}[/red]")
        raise click.Abort from e
