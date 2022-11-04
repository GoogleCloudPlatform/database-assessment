# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
import sys
from pathlib import Path
from typing import Final

import duckdb
import typer
from rich.console import Console
from rich.traceback import install as rich_tracebacks

from dbma import log, transformer, utils
from dbma.__version__ import __version__ as current_version
from dbma.config import settings

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
    archives = _handle_collection_input(collection)
    transformer.engine.upload_to_storage_backend(archives)


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
    logger.info("Configuring SQL Workspace at %s", settings.duckdb_path)
    working_path = settings.temp_path or next(utils.file_helpers.get_temp_dir())
    logger.info("Working Directory set to %s", str(working_path))

    current_config = transformer.schemas.get_config_for_version(current_version)
    archives = _handle_collection_input(collection)
    transformer.engine.upload_to_storage_backend(archives)
    db = duckdb.connect(database=settings.duckdb_path, read_only=False, config={"memory_limit": "500mb"})
    sql = transformer.manager.SQLManager(db, current_config.sql_files_path, current_config.canonical_path)
    sql.execute_pre_processing_scripts()

    collections_to_process = transformer.engine.find_collections(db, archives, working_path)
    transformer.engine.stage_collection_data(collections_to_process)
    transformer.engine.run_assessment(sql)


def _handle_collection_input(collection: Path) -> list[Path]:
    """_summary_

    Args:
        collection (Path): A directory to search for collections or the location to a single file

    Returns:
        list[Path]: a valid list of paths to collections to extract and process
    """
    # setup configuration based on user input
    archive_prefix: Final = "opdb__"
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
    return archives
