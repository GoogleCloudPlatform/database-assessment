import sys
from pathlib import Path

import typer
from rich.console import Console
from rich.traceback import install as rich_tracebacks

from dbma import log, storage, transformer
from dbma.__version__ import __version__ as version
from dbma.config import settings
from dbma.utils.gcp.metadata import GCPMetadata

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
rich_tracebacks(
    console=console,
    suppress=("sqlalchemy", "aiosql", "google", "fsspec", "gcsfs", "duckdb", "duckdb_engine"),
    show_locals=False,
)


@app.command(name="upload-collection")
def upload_collection(
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
    google_project_id: str = typer.Option(
        settings.google_project_id,
        "--google-project-id",
        show_default=True,
        help=(
            "Sets the Google Project ID to use for processing the collection. "
            "This will override the value from the environment."
        ),
    ),
) -> None:
    """Upload a collection to Google"""
    if google_project_id:
        settings.google_project_id = google_project_id
    if collection.is_dir():
        # The path is a directory.  We need to check for zipped archives
        logger.info("🔎 Searching for collection archives in the specified directory")
        collections_to_process = list(collection.glob("*.tar.gz")) + list(collection.glob("*.zip"))
        if len(collections_to_process) < 1:
            logger.error("⚠️ No collection files were found in the specified directory")
            sys.exit(1)
    else:
        collections_to_process = [collection]
    console.log(collection)
    for collection_archive in collections_to_process:
        storage.engine.fs.put_file(collection_archive, f"{settings.collections_path}/upload/")


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
    collection_version: str = typer.Option(
        version,
        "--collection-version",
        "-cv",
        show_default=True,
        help=(
            "Optionally specify the script version to process against. "
            "This is useful if the tooling is unable to detect the script version from the file names."
        ),
    ),
    google_project_id: str = typer.Option(
        settings.google_project_id,
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
    """Process a collection of advisor extracts"""
    if use_gcs:
        settings.storage_backend = "gcs"
    if google_project_id:
        settings.google_project_id = google_project_id
    cloud_detect = GCPMetadata()
    logger.info(cloud_detect.is_running_in_gcp())
    logger.info(cloud_detect.get_project_id())
    logger.info(cloud_detect.get_service_region())
    transformer.engine.process_collection_archives(collection, collection_version)
