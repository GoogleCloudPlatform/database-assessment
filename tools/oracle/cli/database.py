"""Database container management CLI commands."""

from __future__ import annotations

import rich_click as click
from rich.console import Console

console = Console()


@click.group(name="database")
def database_group() -> None:
    """Manage Oracle database container (managed mode).

    Commands for deploying and managing Oracle 23ai Free container.
    Requires Docker or Podman to be installed.
    """


@database_group.command(name="start")
@click.option("--pull", is_flag=True, help="Pull latest image before starting")
@click.option("--recreate", is_flag=True, help="Remove and recreate container if exists")
@click.option("--env-file", type=click.Path(exists=True), help="Environment file to load")
def database_start(pull: bool, recreate: bool, env_file: str | None) -> None:
    """Start Oracle database container.

    Deploys Oracle 23 Free container with configuration matching docker-compose.yml.
    """
    from tools.lib.container import ContainerRuntime
    from tools.oracle.database import DatabaseConfig, OracleDatabase

    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = OracleDatabase(runtime=runtime, config=config, console=console)

        console.print("[yellow]Starting Oracle database container...[/yellow]")
        db.start(pull=pull, recreate=recreate)
        console.print("[green]✓ Database started successfully![/green]")

    except Exception as e:
        console.print(f"[red]✗ Failed to start database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="stop")
@click.option("--timeout", default=30, help="Seconds to wait before forcing stop")
def database_stop(timeout: int) -> None:
    """Stop Oracle database container."""
    from tools.lib.container import ContainerRuntime
    from tools.oracle.database import DatabaseConfig, OracleDatabase

    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = OracleDatabase(runtime=runtime, config=config, console=console)

        if not db.is_running():
            console.print("[yellow]Container is not running[/yellow]")
            return

        console.print("[yellow]Stopping Oracle database container...[/yellow]")
        db.stop(timeout=timeout)
        console.print("[green]✓ Database stopped[/green]")

    except Exception as e:
        console.print(f"[red]✗ Failed to stop database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="restart")
@click.option("--timeout", default=30, help="Seconds to wait for stop")
def database_restart(timeout: int) -> None:
    """Restart Oracle database container."""
    from tools.lib.container import ContainerRuntime
    from tools.oracle.database import DatabaseConfig, OracleDatabase

    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = OracleDatabase(runtime=runtime, config=config, console=console)

        console.print("[yellow]Restarting Oracle database container...[/yellow]")
        db.restart(timeout=timeout)
        console.print("[green]✓ Database restarted[/green]")

    except Exception as e:
        console.print(f"[red]✗ Failed to restart database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="remove")
@click.option("--volumes", is_flag=True, help="Also remove associated volumes")
@click.option("--force", is_flag=True, help="Force removal even if running")
@click.confirmation_option(prompt="Are you sure you want to remove the container?")
def database_remove(volumes: bool, force: bool) -> None:
    """Remove Oracle database container."""
    from tools.lib.container import ContainerRuntime
    from tools.oracle.database import DatabaseConfig, OracleDatabase

    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = OracleDatabase(runtime=runtime, config=config, console=console)

        console.print("[yellow]Removing Oracle database container...[/yellow]")
        db.remove(volumes=volumes, force=force)
        console.print("[green]✓ Database container removed[/green]")

    except Exception as e:
        console.print(f"[red]✗ Failed to remove database: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="logs")
@click.option("--follow", "-f", is_flag=True, help="Follow log output")
@click.option("--tail", type=int, help="Number of lines to show from end")
@click.option("--since", help="Show logs since timestamp/duration")
def database_logs(follow: bool, tail: int | None, since: str | None) -> None:
    """View database container logs."""
    from tools.lib.container import ContainerRuntime
    from tools.oracle.database import DatabaseConfig, OracleDatabase

    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = OracleDatabase(runtime=runtime, config=config, console=console)

        if not db.is_running():
            console.print("[yellow]Container is not running[/yellow]")
            return

        db.logs(follow=follow, tail=tail, since=since)

    except KeyboardInterrupt:
        console.print("\n[dim]Stopped following logs[/dim]")
    except Exception as e:
        console.print(f"[red]✗ Failed to get logs: {e}[/red]")
        raise click.Abort from e


@database_group.command(name="status")
@click.option("--verbose", "-v", is_flag=True, help="Show detailed status")
def database_status(verbose: bool) -> None:
    """Check database container status."""
    from tools.lib.container import ContainerRuntime
    from tools.oracle.database import DatabaseConfig, OracleDatabase

    try:
        runtime = ContainerRuntime()
        config = DatabaseConfig.from_env()
        db = OracleDatabase(runtime=runtime, config=config, console=console)

        status_info = db.status()

        if status_info.exists:
            console.print(f"\n[bold]Container:[/bold] {config.container_name}")
            console.print(f"[bold]Running:[/bold] {'Yes' if status_info.running else 'No'}")
            console.print(f"[bold]Healthy:[/bold] {'Yes' if status_info.healthy else 'Unknown'}")

            if verbose:
                console.print(f"\n[bold]Image:[/bold] {status_info.image}")
                if status_info.created_at:
                    console.print(f"[bold]Created:[/bold] {status_info.created_at}")
                if status_info.uptime:
                    console.print(f"[bold]Uptime:[/bold] {status_info.uptime}")
                if status_info.ports:
                    console.print(f"[bold]Ports:[/bold] {status_info.ports}")
        else:
            console.print(f"[yellow]Container {config.container_name} does not exist[/yellow]")

    except Exception as e:
        console.print(f"[red]✗ Failed to get status: {e}[/red]")
        raise click.Abort from e
