"""Project initialization CLI command."""

from __future__ import annotations

import rich_click as click
from rich.console import Console
from rich.prompt import Confirm, Prompt

from tools.lib.utils import check_env_file, create_env_interactive, detect_deployment_mode

console = Console()


@click.command(name="init")
@click.option(
    "--mode",
    type=click.Choice(["managed", "external"], case_sensitive=False),
    help="Deployment mode (auto-detect if not specified)",
)
@click.option(
    "--run-install",
    is_flag=True,
    help="Automatically run 'install all' after initialization",
)
@click.option(
    "--run-doctor",
    is_flag=True,
    help="Automatically run 'doctor' after initialization",
)
@click.option(
    "--non-interactive",
    is_flag=True,
    help="Skip interactive prompts (use defaults/env vars)",
)
def init_command(mode: str | None, run_install: bool, run_doctor: bool, non_interactive: bool) -> None:
    """Initialize project environment from scratch.

    This command:
    1. Detects or prompts for deployment mode (managed or external)
    2. Creates .env file with interactive prompts for all settings
    3. Configures database connection based on mode
    4. Optionally installs prerequisites
    5. Optionally verifies setup

    Modes:
    - managed: Deploy and manage a PostgreSQL/AlloyDB container (Docker)
    - external: Connect to existing PostgreSQL/AlloyDB database
    """
    console.rule("[bold blue]Project Initialization", style="blue", align="left")
    console.print()

    # Step 1: Determine deployment mode
    if mode is None:
        if check_env_file():
            # .env exists, detect mode from it
            mode = detect_deployment_mode()
            console.print(f"[cyan]🔍 Auto-detected mode from .env: [bold]{mode}[/bold][/cyan]")
        else:
            # No .env, ask user for mode
            console.print("[yellow]📄 No .env file found[/yellow]")
            if non_interactive:
                mode = "managed"
                console.print(f"[cyan]Using default mode: [bold]{mode}[/bold][/cyan]")
            else:
                mode = Prompt.ask(
                    "Select deployment mode",
                    choices=["managed", "external"],
                    default="managed",
                )

        if not non_interactive and check_env_file():
            change = Confirm.ask("Change deployment mode?", default=False)
            if change:
                mode = Prompt.ask(
                    "Select mode",
                    choices=["managed", "external"],
                    default=mode,
                )
    else:
        console.print(f"[cyan]📌 Using specified mode: [bold]{mode}[/bold][/cyan]")

    console.print()

    # Step 2: Create or update .env
    console.print("[yellow]📄 Configuring environment...[/yellow]")
    if not create_env_interactive(mode, non_interactive):
        console.print("[red]✗ Failed to configure .env file[/red]")
        raise click.Abort
    console.print()

    # Step 3: Show next steps based on mode
    console.print(f"[bold]Next steps for [cyan]{mode}[/cyan] mode:[/bold]")
    console.print()

    if mode == "managed":
        console.print("  1. Run: [cyan]python manage.py install all[/cyan]")
        console.print("  2. Run: [cyan]python manage.py database postgres start[/cyan]")
        console.print("  3. Run: [cyan]uv run app db upgrade[/cyan]")
        console.print("  4. Run: [cyan]uv run app db load-fixtures[/cyan]")
    else:  # external
        console.print("  2. Run: [cyan]python manage.py database postgres connect test[/cyan]")
        console.print("  3. Run: [cyan]uv run app db upgrade[/cyan]")
        console.print("  4. Run: [cyan]uv run app db load-fixtures[/cyan]")

    console.print()

    # Step 4: Optional auto-install
    if run_install:
        console.rule("[bold yellow]Running Installation", style="yellow")
        console.print()
        # Import here to avoid circular dependency
        from tools.cli.install import install_all_command

        ctx = click.get_current_context()
        if ctx:
            ctx.invoke(install_all_command, mode=mode, force=False, yes=False)

    # Step 5: Optional auto-doctor
    if run_doctor:
        console.rule("[bold yellow]Running Health Check", style="yellow")
        console.print()
        # Import here to avoid circular dependency
        from tools.cli.doctor import doctor_command

        ctx = click.get_current_context()
        if ctx:
            ctx.invoke(doctor_command, mode=mode, json_output=False, verbose=False)

    # Final message
    console.print()
    console.rule("[bold green]Initialization Complete!", style="green")
    console.print()
    console.print("[bold green]✓ Project initialized successfully![/bold green]")
    console.print()
    console.print("[bold]Next:[/bold]")
    if not run_install:
        console.print("  • Run [cyan]python manage.py install all[/cyan] to install prerequisites")
    if not run_doctor:
        console.print("  • Run [cyan]python manage.py doctor[/cyan] to verify setup")
    console.print("  • Review and update [cyan].env[/cyan] if needed")
    console.print("  • See [cyan]README.md[/cyan] for detailed setup instructions")
    console.print()
