from __future__ import annotations

from typing import TYPE_CHECKING, Literal

from dma.utils import get_engine

from ._utils import RICH_CLICK_INSTALLED, console

if TYPE_CHECKING or not RICH_CLICK_INSTALLED:  # pragma: no cover
    import click
    from click import Context, group, pass_context
else:  # pragma: no cover
    import rich_click as click
    from rich_click import Context, group, pass_context
    from rich_click.cli import patch as rich_click_patch

    rich_click_patch()
    click.rich_click.USE_RICH_MARKUP = True
    click.rich_click.USE_MARKDOWN = False
    click.rich_click.SHOW_ARGUMENTS = True
    click.rich_click.GROUP_ARGUMENTS_OPTIONS = True
    click.rich_click.SHOW_ARGUMENTS = True
    click.rich_click.GROUP_ARGUMENTS_OPTIONS = True
    click.rich_click.STYLE_ERRORS_SUGGESTION = "magenta italic"
    click.rich_click.ERRORS_SUGGESTION = ""
    click.rich_click.ERRORS_EPILOGUE = ""
    click.rich_click.MAX_WIDTH = 80
    click.rich_click.SHOW_METAVARS_COLUMN = True
    click.rich_click.APPEND_METAVARS_HELP = True


__all__ = ("app_group",)


@group(name="DMA", context_settings={"help_option_names": ["-h", "--help"]})
@pass_context
def app_group(ctx: Context) -> None:
    """Database Migration Assessment"""


@app_group.command(
    name="collect-data",
    no_args_is_help=True,
    short_help="Collect data from a source database..",
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
    type=click.STRING,
    required=False,
    show_default=False,
)
def collect_data(
    no_prompt: bool,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"] | None = None,
) -> None:
    """Process a collection of advisor extracts."""
    console.rule("Starting data collection process", align="left")


@app_group.command(
    name="readiness-check",
    no_args_is_help=True,
    short_help="Execute the DMS migration readiness checklist.",
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
    type=click.STRING,
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
def readiness_check(
    no_prompt: bool,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
) -> None:
    """Process a collection of advisor extracts."""
    console.rule("Starting readiness check process", align="left")
    _engine = get_engine(db_type, username, password, hostname, port, database)
