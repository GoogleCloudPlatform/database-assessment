from pathlib import Path

import typer
from rich.console import Console
from rich.traceback import install as rich_tracebacks

from dbma import log, transformer

__all__ = ["console", "app"]

logger = log.get_logger()

TEXT_LOGO = """
[bold yellow]✨ Database Migration Advisor
"""


app = typer.Typer(
    no_args_is_help=True,
    name="Oracle Database Migration Advisor",
    pretty_exceptions_show_locals=False,
    pretty_exceptions_short=True,
)


console = Console(markup=True, emoji=True, color_system="truecolor", stderr=False)
rich_tracebacks(console=console, suppress=("sqlalchemy", "aiosql", "google"), show_locals=False)


@app.command(name="upload-collection")
def upload_collection(
    collection: str = typer.Option(
        ...,
        "--collection",
        "-c",
        exists=True,
        file_okay=True,
        dir_okay=True,
        readable=True,
        resolve_path=True,
        help="Path to collection zip to upload",
    )
) -> None:
    """Upload a collection to Google"""
    console.log(collection)


@app.command(name="process-collection")
def process_collection(
    collection: Path = typer.Option(
        ...,
        "--collection",
        "-c",
        exists=True,
        file_okay=True,
        dir_okay=True,
        readable=True,
        resolve_path=True,
        help="Path to collection zip to upload",
    )
) -> None:
    """Process a collection"""
    logger.info("Dropping existing in-memory tables")
    transformer.sql.drop_all_objects()  # type: ignore[attr-defined]
    logger.info(collection)
