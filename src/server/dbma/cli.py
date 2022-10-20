import sys
from pathlib import Path
from typing import TYPE_CHECKING

import duckdb
import typer
from rich.console import Console
from rich.traceback import install as rich_tracebacks

from dbma import database, log, storage, transformer, utils
from dbma.__version__ import __version__ as version
from dbma.config import settings

if TYPE_CHECKING:
    from dbma.transformer import schemas

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
        archives = list(collection.glob("*.tar.gz")) + list(collection.glob("*.zip"))
        if len(archives) < 1:
            logger.error("⚠️ No collection files were found in the specified directory")
            sys.exit(1)
    else:
        archives = [collection]
    console.log(collection)
    for collection_archive in archives:
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
    # collection_version: str = typer.Option(
    #     version,
    #     "--collection-version",
    #     "-cv",
    #     show_default=True,
    #     help=(
    #         "Optionally specify the script version to process against. "
    #         "This is useful if the tooling is unable to detect the script version from the file names."
    #     ),
    # ),
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
    logger.info("launching Collection loader against %s Google Cloud Project", settings.google_project_id)
    # setup configuration based on user input
    archive_prefix = "opdb__"
    if collection.is_dir():
        # The path is a directory.  We need to check for zipped archives
        logger.info("🔎 Searching for collection archives in the specified directory")

        archives = (
            list(collection.glob(f"{archive_prefix}*.tar.gz"))
            + list(collection.glob(f"{archive_prefix}*.zip"))
            + list(collection.glob(f"{archive_prefix}*.tgz"))
        )
        if len(archives) < 1:
            logger.error("⚠️ No collection files were found in the specified directory")
            sys.exit(1)
    else:
        if collection.stem.startswith(archive_prefix) and collection.suffix in {"gz", "tgz", "zip"}:
            archives = [collection]
        else:
            logger.error("⚠️ The file specified does not appear to be a valid collection archive")
            sys.exit(1)
    working_path = settings.temp_path or next(utils.file_helpers.get_temp_dir())
    db = duckdb.connect(
        database=settings.duckdb_path,
        read_only=False,
        config={"memory_limit": "500mb"},
    )
    op = transformer.schemas.get_config_for_version(version)
    sql = database.SQLManager(db, op.sql_files_path)
    logger.info("Configuring SQL Workspace at %s", settings.duckdb_path)
    logger.info("Working Directory set to %s", str(working_path))
    transformer.engine.upload_to_storage_backend(archives)
    collections_to_process: "list[schemas.Collection]" = transformer.engine.find_collections(db, archives, working_path)
    transformer.engine.stage_collection_data(collections_to_process)
    transformer.engine.run_assessment(sql)
