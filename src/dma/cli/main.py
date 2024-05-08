from __future__ import annotations

import asyncio
from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING, Literal

import click
from click import group, pass_context
from rich import prompt
from rich.table import Table
from sqlalchemy.ext.asyncio import AsyncSession

from dma.__about__ import __version__ as current_version
from dma.cli._utils import console
from dma.collector.dependencies import provide_canonical_queries, provide_collection_query_manager
from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.collector.workflows.readiness_check.base import ReadinessCheck
from dma.lib.db.base import get_engine
from dma.lib.db.local import get_duckdb_connection

if TYPE_CHECKING:
    from rich.console import Console

if TYPE_CHECKING:
    from click import Context

__all__ = ("app",)


@group(name="DMA", context_settings={"help_option_names": ["-h", "--help"]})
@pass_context
def app(ctx: Context) -> None:
    """Database Migration Assessment"""


@app.command(
    name="collect",
    no_args_is_help=True,
    short_help="Collect data from a source database.",
)
@click.option(
    "--no-prompt",
    help="Do not prompt for confirmation before executing check.",
    type=bool,
    default=False,
    required=False,
    show_default=True,
    is_flag=True,
)
@click.option(
    "--db-type",
    "-db",
    help="The type of the database to connect to",
    default=None,
    type=click.Choice({"mysql", "postgres", "oracle", "mssql"}),
    required=False,
    show_default=False,
)
@click.option(
    "--username",
    "-u",
    help="The database user to connect as.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--password",
    "-pw",
    help="The database user password.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--hostname",
    "-h",
    help="The hostname of the database server",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--port",
    "-p",
    help="The port of the database server",
    default=None,
    type=click.INT,
    required=False,
    show_default=False,
)
@click.option(
    "--database",
    "-d",
    help="The name of the database to connect to.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--collection-identifier",
    "-id",
    help="An optional identifier used to tag the collection.  If one is not provided, the identifier will be generated from the database configuration.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
def collect_data(
    no_prompt: bool,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str | None = None,
    password: str | None = None,
    hostname: str | None = None,
    port: int | None = None,
    database: str | None = None,
    collection_identifier: str | None = None,
) -> None:
    """Process a collection of advisor extracts."""
    print_app_info()
    console.rule("Starting data collection process", align="left")

    if hostname is None:
        hostname = prompt.Prompt.ask("Please enter a hostname for the database")
    if port is None:
        port = prompt.IntPrompt.ask("Please enter a port for the database")
    if database is None:
        database = prompt.Prompt.ask("Please enter a database name")
    if username is None:
        username = prompt.Prompt.ask("Please enter a username")
    if password is None:
        password = prompt.Prompt.ask("Please enter a password", password=True)
    if no_prompt:
        input_confirmed = True
    if not no_prompt:
        input_confirmed = prompt.Confirm.ask("Are you ready to start the assessment?")
    if input_confirmed:
        asyncio.run(
            _collect_data(
                console=console,
                db_type=db_type,
                username=username,
                password=password,
                hostname=hostname,
                port=port,
                database=database,
                collection_identifier=collection_identifier,
            )
        )
    else:
        console.rule("Skipping execution until input is confirmed", align="left")


async def _collect_data(
    console: Console,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
    collection_identifier: str | None,
    working_path: Path | None = None,
) -> None:
    async_engine = get_engine(db_type, username, password, hostname, port, database)
    working_path = working_path or Path("tmp/")
    execution_id = f"{db_type}_{current_version!s}_{datetime.now(tz=timezone.utc).strftime('%y%m%d%H%M%S')}"
    with get_duckdb_connection(working_path) as local_db:
        async with AsyncSession(async_engine) as db_session:
            collection_manager = await anext(
                provide_collection_query_manager(
                    db_session=db_session, execution_id=execution_id, manual_id=collection_identifier
                )
            )
            canonical_query_manager = next(provide_canonical_queries(local_db=local_db, working_path=working_path))
            collection_extractor = CollectionExtractor(
                local_db=local_db,
                canonical_query_manager=canonical_query_manager,
                collection_query_manager=collection_manager,
                db_type=db_type,
                console=console,
            )
            await collection_extractor.execute()
            collection_extractor.dump_database(working_path)
        await async_engine.dispose()


@app.command(
    name="readiness-check",
    no_args_is_help=True,
    short_help="Quickly check the compatibility of your database with CloudSQL and AlloyDB.",
)
@click.option(
    "--no-prompt",
    help="Do not prompt for confirmation before executing check.",
    type=bool,
    default=False,
    required=False,
    show_default=True,
    is_flag=True,
)
@click.option(
    "--db-type",
    "-db",
    help="The type of the database to connect to",
    default=None,
    type=click.Choice({"mysql", "postgres", "oracle", "mssql"}),
    required=False,
    show_default=False,
)
@click.option(
    "--username",
    "-u",
    help="The database user to connect as.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--password",
    "-pw",
    help="The database user password.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--hostname",
    "-h",
    help="The hostname of the database server",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--port",
    "-p",
    help="The port of the database server",
    default=None,
    type=click.INT,
    required=False,
    show_default=False,
)
@click.option(
    "--database",
    "-d",
    help="The name of the database to connect to.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
@click.option(
    "--collection-identifier",
    "-id",
    help="An optional identifier used to tag the collection.  If one is not provided, the identifier will be generated from the database configuration.",
    default=None,
    type=click.STRING,
    required=False,
    show_default=False,
)
def readiness_assessment(
    no_prompt: bool,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str | None = None,
    password: str | None = None,
    hostname: str | None = None,
    port: int | None = None,
    database: str | None = None,
    collection_identifier: str | None = None,
) -> None:
    """Process a collection of advisor extracts."""
    print_app_info()
    console.rule("Starting data collection process", align="left")

    if hostname is None:
        hostname = prompt.Prompt.ask("Please enter a hostname for the database")
    if port is None:
        port = prompt.IntPrompt.ask("Please enter a port for the database")
    if database is None:
        database = prompt.Prompt.ask("Please enter a database name")
    if username is None:
        username = prompt.Prompt.ask("Please enter a username")
    if password is None:
        password = prompt.Prompt.ask("Please enter a password", password=True)
    if no_prompt:
        input_confirmed = True
    if not no_prompt:
        input_confirmed = prompt.Confirm.ask("Are you ready to start the assessment?")
    if input_confirmed:
        asyncio.run(
            _readiness_check(
                console=console,
                db_type=db_type,
                username=username,
                password=password,
                hostname=hostname,
                port=port,
                database=database,
                collection_identifier=collection_identifier,
            )
        )
    else:
        console.rule("Skipping execution until input is confirmed", align="left")


async def _readiness_check(
    console: Console,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
    collection_identifier: str | None,
    working_path: Path | None = None,
) -> None:
    async_engine = get_engine(db_type, username, password, hostname, port, database)
    working_path = working_path or Path("tmp/")
    execution_id = f"{db_type}_{current_version!s}_{datetime.now(tz=timezone.utc).strftime('%y%m%d%H%M%S')}"
    with get_duckdb_connection(working_path) as local_db:
        async with AsyncSession(async_engine) as db_session:
            collection_manager = await anext(
                provide_collection_query_manager(
                    db_session=db_session, execution_id=execution_id, manual_id=collection_identifier
                )
            )
            canonical_query_manager = next(provide_canonical_queries(local_db=local_db, working_path=working_path))
            workflow = ReadinessCheck(
                local_db=local_db,
                canonical_query_manager=canonical_query_manager,
                collection_query_manager=collection_manager,
                db_type=db_type,
                console=console,
            )
            await workflow.execute()
        await async_engine.dispose()


def print_app_info() -> None:
    table = Table(show_header=False)
    table.add_column("title", style="cyan", width=80)
    table.add_row(
        f"[bold green]Google Database Migration Assessment[/]                [cyan]version {current_version}[/]"
    )
    console.print(table, width=80)
