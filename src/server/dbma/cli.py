import sys
from pathlib import Path
from typing import Optional

import typer
from rich.console import Console
from rich.traceback import install as rich_tracebacks

from dbma import log, storage, transformer
from dbma.config import settings
from dbma.utils.gcp.detect import GCPDetector

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
    add_completion=False,
)


console = Console(markup=True, emoji=True, color_system="truecolor", stderr=False)
rich_tracebacks(console=console, suppress=("sqlalchemy", "aiosql", "google", "fsspec", "gcsfs"), show_locals=False)


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


@app.command(
    name="process-collection", no_args_is_help=True, short_help="This command processes one or more collections."
)
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
    ),
    collection_version: Optional[str] = typer.Option(
        None,
        "--collection-version",
        "-cv",
        show_default=True,
        help=(
            "Optionally specify the script version to process against. "
            "This is useful if the tooling is unable to detect the script version from the file names."
        ),
    ),
    google_project_id: Optional[str] = typer.Option(
        None,
        "--google-project-id",
        show_default=True,
        help=(
            "Sets the Google Project ID to use for processing the collection. "
            "This will override the value from the environment."
        ),
    ),
    use_gcs: bool = typer.Option(
        settings.storage_backend == "gcs",
        "--use-gcs",
        show_default=True,
        help=("Upload and store files in GCS "),
    ),
) -> None:
    """Process a collection"""
    if use_gcs:
        settings.storage_backend = "gcs"
    if google_project_id:
        settings.google_project_id = google_project_id
    # setup configuration based on user input
    if collection.is_dir():
        # The path is a directory.  We need to check for zipped archives
        logger.info("Searching for collection archives in the specified directory")
        collections_to_process = list(collection.glob("*.tar.gz")) + list(collection.glob("*.zip"))
        if len(collections_to_process) < 1:
            logger.error("[bold red]No collection files were found in the specified directory")
            sys.exit(1)
    else:
        collections_to_process = [collection]

    # handled parsed list of collection paths
    filenames = [f"{c.stem}{c.suffix}" for c in collections_to_process]
    logger.info("=> Processing %d collection(s)", len(filenames))
    logger.info("=> Collections to process: %s", filenames)
    transformer.process_collection(
        collections=collections_to_process,
        extract_path=next(transformer.get_temp_dir()),
        parse_as_version=collection_version,
    )
    # transformer.sql.drop_all_objects()  # type: ignore[attr-defined]
    # transformer.sql.create_schema()  # type: ignore[attr-defined]
    dirs = storage.engine.fs.ls(settings.collections_path)
    logger.info(dirs)
    cloud_detect = GCPDetector()
    logger.info(cloud_detect.is_running_in_gcp())
