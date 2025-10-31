"""CLI commands for PostgreSQL database container management."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

from tools.lib.container import ContainerRuntime, NoRuntimeAvailableError
from tools.postgres.database import DatabaseConfig, PostgreSQLDatabase

console = Console()


def _exit_on_failure(success: bool) -> None:
    if not success:
        raise click.exceptions.Exit(1)  # pyright: ignore


@click.group(name="database")
def database_group() -> None:
    """Manage PostgreSQL database container lifecycle.

    Commands for starting, stopping, and managing the PostgreSQL/AlloyDB Omni container.
    """


@database_group.command(name="start")
@click.option("--pull", is_flag=True, help="Pull latest image before starting")
@click.option("--recreate", is_flag=True, help="Remove and recreate container if exists")
def start_database(pull: bool, recreate: bool) -> None:
    """Start PostgreSQL database container.

    This command starts a PostgreSQL/AlloyDB Omni container with the following features:
    - Persistent data storage using Docker volumes
    - Automatic health checks
    - Configurable via environment variables
    - Auto-restart on failure

    Environment Variables:
        DATABASE_PORT: Host port (default: 15432)
        DATABASE_PASSWORD: PostgreSQL password (default: super-secret)
        DATABASE_USER: PostgreSQL user (default: app)
        DATABASE_NAME: Database name (default: app)

    Examples:
        # Start database with default settings
        python manage.py database postgres start

        # Pull latest image and start
        python manage.py database postgres start --pull

        # Recreate container
        python manage.py database postgres start --recreate
    """
    try:
        runtime = ContainerRuntime()
        if not runtime.is_available():
            console.print("[red]No container runtime (Docker/Podman) found[/red]")
            _exit_on_failure(False)

        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

        db.start(pull=pull, recreate=recreate)

    except NoRuntimeAvailableError as e:
        console.print(f"[red]Error: {e}[/red]")
        raise click.Abort from e
    except Exception as e:
        console.print(f"[red]Failed to start database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="stop")
def stop_database() -> None:
    """Stop PostgreSQL database container.

    Gracefully stops the running PostgreSQL container. The data is preserved
    in the Docker volume and will be available when the container is restarted.

    Example:
        python manage.py database postgres stop
    """
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

        db.stop()

    except Exception as e:
        console.print(f"[red]Failed to stop database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="restart")
def restart_database() -> None:
    """Restart PostgreSQL database container.

    Restarts the PostgreSQL container. If the container doesn't exist,
    it will be created and started.

    Example:
        python manage.py database postgres restart
    """
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

        db.restart()

    except Exception as e:
        console.print(f"[red]Failed to restart database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="status")
def status_database() -> None:
    """Show PostgreSQL database container status.

    Displays detailed information about the database container including:
    - Container status (running, stopped, etc.)
    - Container ID
    - Image name
    - Port mappings
    - Creation timestamp

    Example:
        python manage.py database postgres status
    """
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

        status = db.status()

        console.rule("[bold blue]PostgreSQL Database Status")
        console.print(f"[bold]Container:[/bold] {status.get('name', 'N/A')}")
        console.print(f"[bold]Status:[/bold] {status.get('status', 'N/A')}")
        console.print(f"[bold]ID:[/bold] {status.get('id', 'N/A')}")
        console.print(f"[bold]Image:[/bold] {status.get('image', 'N/A')}")
        console.print(f"[bold]Ports:[/bold] {status.get('ports', 'N/A')}")
        console.print(f"[bold]Created:[/bold] {status.get('created', 'N/A')}")

    except Exception as e:
        console.print(f"[red]Failed to get status: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="logs")
@click.option("-f", "--follow", is_flag=True, help="Follow log output")
@click.option("--tail", default=50, help="Number of lines to show from end")
def logs_database(follow: bool, tail: int) -> None:
    """Display PostgreSQL database container logs.

    Shows logs from the PostgreSQL container. Use --follow to stream logs in real-time.

    Examples:
        # Show last 50 lines
        python manage.py database postgres logs

        # Follow logs in real-time
        python manage.py database postgres logs --follow

        # Show last 100 lines
        python manage.py database postgres logs --tail 100
    """
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

        db.logs(follow=follow, tail=tail)

    except Exception as e:
        console.print(f"[red]Failed to get logs: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="remove")
@click.option("--force", is_flag=True, help="Force removal even if running")
@click.confirmation_option(prompt="Are you sure you want to remove the database container?")
def remove_database(force: bool) -> None:
    """Remove PostgreSQL database container.

    CAUTION: This removes the container but preserves the data volume.
    To completely wipe all data, use 'wipe' command instead.

    Example:
        python manage.py database postgres remove --force
    """
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

        db.remove(force=force)

    except Exception as e:
        console.print(f"[red]Failed to remove container: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="wipe")
@click.confirmation_option(prompt="⚠️  This will DELETE ALL DATABASE DATA. Are you absolutely sure?")
def wipe_database() -> None:
    """Completely wipe database container and data.

    ⚠️  WARNING: This will permanently delete all database data!

    This command:
    1. Removes the database container (forced)
    2. Deletes the data volume
    3. All data will be lost permanently

    Example:
        python manage.py database postgres wipe
    """
    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = PostgreSQLDatabase(runtime, config, console)

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
    """Check health of PostgreSQL deployment.

    Performs comprehensive health checks including:
    - Container runtime availability (Docker/Podman)
    - Database container status
    - PostgreSQL connectivity
    - psql CLI availability (optional)

    Examples:
        # Basic health check
        python manage.py database postgres health

        # Detailed health check
        python manage.py database postgres health --verbose
    """
    from tools.postgres.health import HealthChecker

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
    """Test database connection.

    Examples:
        python manage.py database postgres connect test
        python manage.py database postgres connect test --timeout 30
    """
    from tools.postgres.connection import ConnectionConfig, ConnectionTester

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
    """Display connection information.

    Example:
        python manage.py database postgres connect info
    """
    from tools.postgres.connection import ConnectionTester

    try:
        tester = ConnectionTester(console=console)
        info = ConnectionTester.get_connection_info()
        tester.display_connection_info(info)

    except Exception as e:
        console.print(f"[red]Failed to get connection info: {e}[/red]")
        raise click.Abort from e
