#!/usr/bin/env python3
# /// script
# requires-python = ">=3.11"
# dependencies = [
#     "httpx>=0.28.1",
#     "rich-click>=1.8.0",
#     "asyncpg>=0.30.0",
#     "python-dotenv>=1.0.0",
# ]
# ///
"""Unified project management CLI for PostgreSQL + Vertex AI demo.

This tool provides a single interface for:
- Project initialization and environment setup
- Prerequisite installation (UV, etc.)
- PostgreSQL/AlloyDB connection testing

IMPORTANT: This is a development tool and should not be shipped with production code.

Usage:
    python manage.py init                  # Initialize project
    python manage.py install all          # Install all prerequisites
    python manage.py doctor               # Verify setup
    python manage.py --help               # Show all commands
"""

from __future__ import annotations

import sys
from pathlib import Path

import rich_click as click
from rich.console import Console

# Ensure tools package is importable
sys.path.insert(0, str(Path(__file__).parent))

# Import project management CLI commands
from tools.cli import doctor_command, init_command, install_group
from tools.mysql import (
    database_group as mysql_database_group,
)
from tools.oracle import (
    database_group as oracle_database_group,
)
from tools.postgres import database_group as postgres_database_group
from tools.sqlserver import (
    database_group as sqlserver_database_group,
)

console = Console()

# Configure rich-click
click.rich_click.USE_RICH_MARKUP = True
click.rich_click.SHOW_ARGUMENTS = True
click.rich_click.GROUP_ARGUMENTS_OPTIONS = True
click.rich_click.STYLE_ERRORS_SUGGESTION = "yellow italic"
click.rich_click.ERRORS_SUGGESTION = "Try running the '--help' flag for more information."


# ============================================================================
# Main CLI Group
# ============================================================================


@click.group()
@click.version_option(version="0.2.0", prog_name="manage")
def cli() -> None:
    """Unified DevOps CLI for PostgreSQL + Vertex AI Demo.

    This tool manages project initialization, prerequisites, and database setup
    for PostgreSQL/AlloyDB connections.

    Common workflow:
      1. python manage.py init              # Set up .env
      2. python manage.py install all       # Install prerequisites
      3. python manage.py doctor            # Verify setup
      4. make start-infra                   # Start AlloyDB Omni container (via Makefile)

    For help on any command:
      python manage.py <command> --help
    """


# ============================================================================
# Register Project Management Commands
# ============================================================================

# Register init command
cli.add_command(init_command, name="init")

# Register install group
cli.add_command(install_group, name="install")

# Register doctor command
cli.add_command(doctor_command, name="doctor")


# ============================================================================
# Register PostgreSQL Database Commands
# ============================================================================


@cli.group(name="database")
def database_cli_group() -> None:
    """Manage database operations.

    Commands for database management across different providers.
    """


@database_cli_group.group(name="postgres")
def postgres_cli_group() -> None:
    """Manage PostgreSQL/AlloyDB database operations.

    Commands for deploying and managing PostgreSQL/AlloyDB containers.
    Requires Docker for managed mode.
    """


@database_cli_group.group(name="oracle")
def oracle_cli_group() -> None:
    """Manage Oracle database operations.

    Commands for deploying and managing Oracle databases, wallets, and connections.
    Requires Docker or Podman for managed mode.
    """


@database_cli_group.group(name="mysql")
def mysql_cli_group() -> None:
    """Manage MySQL database operations.

    Commands for deploying and managing MySQL database operations.
    Requires Docker or Podman for managed mode.
    """


@database_cli_group.group(name="mssql")
def sqlserver_cli_group() -> None:
    """Manage SQL Server database operations.

    Commands for deploying and managing SQL Server databases.
    Requires Docker or Podman for managed mode.
    """


# Register database commands under postgres_cli_group
for command_name, command in postgres_database_group.commands.items():
    postgres_cli_group.add_command(command, name=command_name)


# Register database commands under oracle_cli_group
for command_name, command in oracle_database_group.commands.items():
    oracle_cli_group.add_command(command, name=command_name)

# Register database commands under mysql_cli_group
for command_name, command in mysql_database_group.commands.items():
    mysql_cli_group.add_command(command, name=command_name)

# Register database commands under sqlserver_cli_group
for command_name, command in sqlserver_database_group.commands.items():
    sqlserver_cli_group.add_command(command, name=command_name)

# ============================================================================
# Main Entry Point
# ============================================================================


def main() -> None:
    """Main entry point."""
    try:
        cli()
    except KeyboardInterrupt:
        console.print("\n[yellow]Interrupted by user[/yellow]")
        sys.exit(130)
    except Exception as e:  # noqa: BLE001
        console.print(f"[red]Error: {e}[/red]")
        sys.exit(1)


if __name__ == "__main__":
    main()
