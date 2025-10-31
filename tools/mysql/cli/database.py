"""CLI commands for MySQL database container management."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

from tools.lib.container import ContainerRuntime, NoRuntimeAvailableError
from tools.mysql.database import DatabaseConfig, MySQLDatabase

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="database")
def database_group() -> None:
    """Manage MySQL database container lifecycle."""


@database_group.command(name="start")
@click.option("--pull", is_flag=True, help="Pull latest image before starting")
@click.option("--recreate", is_flag=True, help="Remove and recreate container if exists")
def start_database(pull: bool, recreate: bool) -> None:
    """Start MySQL database container."""
    try:
        runtime = ContainerRuntime()
        if not runtime.is_available():
            console.print("[red]No container runtime (Docker/Podman) found[/red]")
            _exit_on_failure(False)

        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        db.start(pull=pull, recreate=recreate)
        console.print("[green]✓ Database started successfully![/green]")

    except NoRuntimeAvailableError as e:
        console.print(f"[red]Error: {e}[/red]")
        raise click.Abort from e
    except Exception as e:
        console.print(f"[red]Failed to start database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="stop")
@click.option("--timeout", default=30, help="Seconds to wait before forcing stop")
def stop_database(timeout: int) -> None:
    """Stop MySQL database container."""
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        if not db.is_running():
            console.print("[yellow]Container is not running[/yellow]")
            return

        console.print("[yellow]Stopping MySQL database container...[/yellow]")
        db.stop()
        console.print("[green]✓ Database stopped[/green]")

    except Exception as e:
        console.print(f"[red]Failed to stop database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="restart")
@click.option("--timeout", default=30, help="Seconds to wait for stop")
def restart_database(timeout: int) -> None:
    """Restart MySQL database container."""
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        console.print("[yellow]Restarting MySQL database container...[/yellow]")
        db.restart()
        console.print("[green]✓ Database restarted[/green]")

    except Exception as e:
        console.print(f"[red]Failed to restart database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="status")
@click.option("--verbose", "-v", is_flag=True, help="Show detailed status")
def status_database(verbose: bool) -> None:
    """Show MySQL database container status."""
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        status_info = db.status()

        if status_info.get("exists"):
            console.print(f"\n[bold]Container:[/bold] {config.container_name}")
            console.print(f"[bold]Running:[/bold] {'Yes' if status_info.get('running') else 'No'}")
            console.print(f"[bold]Healthy:[/bold] {'Yes' if status_info.get('healthy') else 'Unknown'}")

            if verbose:
                console.print(f"\n[bold]Image:[/bold] {status_info.get('image')}")
                if status_info.get("created_at"):
                    console.print(f"[bold]Created:[/bold] {status_info.get('created_at')}")
                if status_info.get("uptime"):
                    console.print(f"[bold]Uptime:[/bold] {status_info.get('uptime')}")
                if status_info.get("ports"):
                    console.print(f"[bold]Ports:[/bold] {status_info.get('ports')}")
        else:
            console.print(f"[yellow]Container {config.container_name} does not exist[/yellow]")

    except Exception as e:
        console.print(f"[red]Failed to get status: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="logs")
@click.option("-f", "--follow", is_flag=True, help="Follow log output")
@click.option("--tail", default=50, help="Number of lines to show from end")
def logs_database(follow: bool, tail: int) -> None:
    """Display MySQL database container logs."""
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        if not db.is_running():
            console.print("[yellow]Container is not running[/yellow]")
            return

        db.logs(follow=follow, tail=tail)

    except KeyboardInterrupt:
        console.print("\n[dim]Stopped following logs[/dim]")
    except Exception as e:
        console.print(f"[red]Failed to get logs: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="remove")
@click.option("--force", is_flag=True, help="Force removal even if running")
@click.confirmation_option(prompt="Are you sure you want to remove the database container?")
def remove_database(force: bool) -> None:
    """Remove MySQL database container."""
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        console.print("[yellow]Removing MySQL database container...[/yellow]")
        db.remove(force=force)
        console.print("[green]✓ Database container removed[/green]")

    except Exception as e:
        console.print(f"[red]Failed to remove container: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="wipe")
@click.confirmation_option(prompt="⚠️  This will DELETE ALL DATABASE DATA. Are you absolutely sure?")
def wipe_database() -> None:
    """Completely wipe database container and data."""
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = MySQLDatabase(runtime=runtime, config=config, console=console)

        console.rule("[bold red]⚠️  Wiping Database")

        # Remove container
        db.remove(force=True)

        # Remove volume
        if runtime.volume_exists(config.data_volume_name):
            console.print(f"[yellow]Removing data volume {config.data_volume_name}...[/yellow]")
            runtime.run_command(["volume", "rm", config.data_volume_name], check=True)
            console.print("[green]✓[/green] Data volume removed")
        else:
            console.print("[yellow]Data volume does not exist[/yellow]")

        console.print("\n[bold red]All database data has been permanently deleted[/bold red]")

    except Exception as e:
        console.print(f"[red]Failed to wipe database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="health")
@click.option("--verbose", "-v", is_flag=True, help="Show detailed health information")
def health_check(verbose: bool) -> None:
    """Check health of MySQL deployment."""
    from tools.mysql.health import HealthChecker

    try:
        checker = HealthChecker(console=console)
        health = checker.check_all(verbose=verbose)
        checker.display_health(health, verbose=verbose)

        # Exit with error code if unhealthy
        _exit_on_failure(health.is_healthy)

    except Exception as e:
        console.print(f"[red]Health check failed: {e}[/red]")
        raise click.Abort from e


# Add connect subgroup
@database_group.group(name="connect")
def connect_subgroup() -> None:
    """Test and manage database connections."""


@connect_subgroup.command(name="test")
@click.option("--timeout", default=10, help="Connection timeout in seconds")
def test_connection(timeout: int) -> None:
    """Test database connection."""
    from tools.mysql.connection import ConnectionConfig, ConnectionTester

    try:
        tester = ConnectionTester(console=console)
        config = ConnectionConfig.from_env()

        console.print("[cyan]Testing connection...[/cyan]")
        result = tester.test(config, timeout=timeout, display=True)

        _exit_on_failure(result.success)

    except Exception as e:
        console.print(f"[red]Connection test failed: {e}[/red]")
        raise click.Abort from e


@connect_subgroup.command(name="info")
def connection_info() -> None:
    """Display connection information."""
    from tools.mysql.connection import ConnectionTester

    try:
        tester = ConnectionTester(console=console)
        info = ConnectionTester.get_connection_info()
        tester.display_connection_info(info)

    except Exception as e:
        console.print(f"[red]Failed to get connection info: {e}[/red]")
        raise click.Abort from e
