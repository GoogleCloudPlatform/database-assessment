# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path
from typing import TYPE_CHECKING, Literal

import click
from click import group, pass_context
from rich import prompt
from rich.padding import Padding
from rich.table import Table

from dma.__about__ import __version__ as current_version
from dma.cli._utils import console
from dma.collector.dependencies import provide_canonical_queries
from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.collector.workflows.readiness_check.base import ReadinessCheck
from dma.lib.db.base import SourceInfo
from dma.lib.db.local import get_duckdb_connection

if TYPE_CHECKING:
    from click import Context
    from rich.console import Console

__all__ = ("app",)


@group(name="DMA", context_settings={"help_option_names": ["-h", "--help"]})
@pass_context
def app(ctx: Context) -> None:
    """Database Migration Assessment"""


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
    type=click.Choice(["mysql", "postgres", "oracle", "mssql"]),
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
    input_confirmed = True if no_prompt else prompt.Confirm.ask("Are you ready to start the assessment?")
    if input_confirmed:
        _collect_data(
            console=console,
            src_info=SourceInfo(
                db_type=db_type.upper(),  # type: ignore[arg-type]
                username=username,
                password=password,
                hostname=hostname,
                port=port,
            ),
            database=database,
            collection_identifier=collection_identifier,
        )
    else:
        console.rule("Skipping execution until input is confirmed", align="left")


def _collect_data(
    console: Console,
    src_info: SourceInfo,
    database: str,
    collection_identifier: str | None,
    working_path: Path | None = None,
) -> None:
    working_path = working_path or Path("tmp/")
    _execution_id = f"{src_info.db_type}_{current_version!s}_{datetime.now(tz=timezone.utc).strftime('%y%m%d%H%M%S')}"
    with get_duckdb_connection(working_path) as local_db:
        canonical_query_manager = next(provide_canonical_queries(local_db=local_db, working_path=working_path))
        collection_extractor = CollectionExtractor(
            local_db=local_db,
            src_info=src_info,
            database=database,
            canonical_query_manager=canonical_query_manager,
            console=console,
            collection_identifier=collection_identifier,
        )
        collection_extractor.execute()
        collection_extractor.dump_database(working_path)


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
@click.option(
    "--export",
    "-wp",
    help="Path to export the results.",
    default=None,
    type=click.Path(),
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
    export: str | None = None,
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
    input_confirmed = True if no_prompt else prompt.Confirm.ask("Are you ready to start the assessment?")
    if input_confirmed:
        _readiness_check(
            console=console,
            src_info=SourceInfo(
                db_type=db_type.upper(),  # type: ignore[arg-type]
                username=username,
                password=password,
                hostname=hostname,
                port=port,
            ),
            database=database,
            collection_identifier=collection_identifier,
            export_path=Path(export) if export else None,
        )
    else:
        console.rule("Skipping execution until input is confirmed", align="left")


def _readiness_check(
    console: Console,
    src_info: SourceInfo,
    database: str,
    collection_identifier: str | None,
    working_path: Path | None = None,
    export_path: Path | None = None,
    export_delimiter: str = "|",
) -> None:
    _execution_id = f"{src_info.db_type}_{current_version!s}_{datetime.now(tz=timezone.utc).strftime('%y%m%d%H%M%S')}"
    with get_duckdb_connection(working_path) as local_db:
        workflow = ReadinessCheck(
            local_db=local_db,
            src_info=src_info,
            database=database,
            console=console,
            collection_identifier=collection_identifier,
            working_path=working_path,
        )
        workflow.execute()
        console.print(Padding("", 1, expand=True))
        console.rule("Processing collected data.", align="left")
        workflow.print_summary()
        if workflow.collection_extractor is not None and export_path is not None:
            workflow.collection_extractor.dump_database(export_path=export_path, delimiter=export_delimiter)
        console.rule("Assessment complete.", align="left")


def print_app_info() -> None:
    table = Table(show_header=False)
    table.add_column("title", style="cyan", width=80)
    table.add_row(
        f"[bold green]Google Database Migration Assessment[/]                [cyan]version {current_version}[/]"
    )
    console.print(table)
