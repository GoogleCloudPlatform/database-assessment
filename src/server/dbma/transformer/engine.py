# nosec: B608
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
import re
import tarfile as tf
import zipfile as zf
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import TYPE_CHECKING, Any, Union

import fsspec
from packaging.version import LegacyVersion, Version
from pydantic import ValidationError

from dbma import log, storage, utils
from dbma.__version__ import __version__ as version
from dbma.config import settings
from dbma.transformer import manager, schemas
from dbma.transformer.loaders import CSVTransformer

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection

__all__ = ["run_assessment", "find_collections", "upload_to_storage_backend", "stage_collection_data"]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


local_fs = fsspec.filesystem("file")


def stage_collection_data(collections_to_process: "list[schemas.Collection]") -> None:
    """Load discovered collection archives

    Args:
        files (list[Path]): _description_
        local_working_path (Union[TemporaryDirectory , Path]): _description_
        parse_as_version (str): _description_

    Raises:
        FileNotFoundError: _description_
    """

    for collection in collections_to_process:
        for file_type in collection.files.__fields__:
            file_path = getattr(collection.files, file_type)
            if file_path and file_path.stat().st_size > 0:
                csv = CSVTransformer(file_path=file_path, delimiter=collection.files.delimiter, schema_type=file_type)
                csv.to_parquet(settings.collections_path)
        logger.info("converted all files to parquet for collection %s", collection.collection_id)

    for collection in collections_to_process:
        collection.queries.execute_load_scripts(collection)


def find_collections(
    db: "DuckDBPyConnection", archives: list["Path"], extract_path: "Union[TemporaryDirectory , Path]"
) -> "list[schemas.Collection]":
    """Process the collection"""
    # override or detect version to process with
    valid_collections: "list[schemas.Collection]" = []
    # loop through collections and extract them
    for extract in archives:
        script_version = utils.file_helpers.get_version_from_file(extract)
        version_config = schemas.get_config_for_version(str(script_version))
        db_version = utils.file_helpers.get_db_version_from_file(extract)
        collection_key = utils.file_helpers.get_collection_key_from_file(extract)
        collection_id = utils.file_helpers.get_collection_id_from_key(collection_key)

        logger.info('ℹ️  detected version "%s" from the collection name', script_version)
        files = _parse_and_validate_archive(collection_id, extract, extract_path)
        try:
            valid_collections.append(
                schemas.Collection.parse_obj(
                    {
                        "config": schemas.get_config_for_version(str(script_version)),
                        "files": version_config.collection_files_schema.from_file_list(files),
                        "collection_id": collection_id,
                        "collection_key": collection_key,
                        "script_version": script_version,
                        "db_version": db_version,
                        "queries": manager.SQLManager(db, version_config.sql_files_path, version_config.canonical_path),
                    }
                )
            )
        except ValidationError as e:
            logger.error("⚠️ [bold red]failed to validate files contained in collections: %s", e.errors)
            raise e from e
    return valid_collections


def upload_to_storage_backend(collections: list[Path]) -> None:
    """Store archive to storage backend"""
    for archive in collections:
        storage_path = f"{settings.collections_path}/upload/{archive.stem}{archive.suffix}"
        storage.engine.fs.mkdir(storage_path, create_parents=True)
        storage.engine.fs.put(str(archive), storage_path)
    logger.info("Data Uploaded to storage backend")


def run_assessment(queries: "manager.SQLManager") -> None:
    """Execute an assessment"""
    logger.info("Launching assessment using version %s", version)
    rows: dict[str, Any] = {}
    queries.execute_transformation_scripts()
    database_metrics = queries.get_db_metrics()  # type: ignore[attr-defined]
    database_features = queries.get_db_features()  # type: ignore[attr-defined]
    rows.update(
        {
            "database_metrics": database_metrics,
            "database_features": database_features,
        }
    )
    for key, value in rows.items():
        logger.info("Loaded %s records for %s", len(value), key)


def _parse_and_validate_archive(
    collection_id: str, collection_archive: "Path", extract_path: "Union[TemporaryDirectory,Path]"
) -> "list[Path]":
    """Extracts the specified collection to the specified directory.

    *Note* -
    - This function will also rename files with a *.log to a *.csv extension.
    2.X.X versions of the collector scripts used this convention
    - It will remove all blank lines from any CSV.  Some version of the script have a line skipped before the headers.
    - Remove `Elapsed` total at the end of extracts.
    SQLPLUS output sometimes was executed with timing.  This removes it



    Args:
        collection_id (str): the collection ID of the archive you are extracting.
        collection_archive (Path): the archive to extract
        extract_path (Union[TemporaryDirectory,Path]): where to extract the collection

    Returns:
        list[Path]: A list containing `Path` objects for each extracted file
    """

    logger.info("🔎 searching %s for files and extracting to %s", collection_archive.name, extract_path)
    if collection_archive.suffix in {".gz", ".tgz"}:
        with tf.TarFile.open(collection_archive, "r|gz") as archive:
            archive.extractall(str(extract_path))
    elif collection_archive.suffix in {".zip"}:
        with zf.ZipFile(collection_archive, "r") as archive:
            archive.extractall(str(extract_path))
    files_to_rename = list(Path(str(extract_path)).glob(f"*{collection_id}.log"))
    for file_to_rename in files_to_rename:
        file_to_rename.rename(f"{file_to_rename.parent}/{file_to_rename.stem}.csv")
    logger.info("renamed %i files in collection %s", len(files_to_rename), collection_id)
    csv_files = list(Path(str(extract_path)).glob(f"*{collection_id}.csv"))

    for csv_file in csv_files:
        with open(csv_file, "r+", encoding="utf8") as f:
            content = f.readlines()
            f.seek(0)
            for line in content:
                if line.strip() != "" and not re.match(r"^Elapsed: (\d+):(\d+):(\d+).(\d+)$", line):
                    f.write(line)
            f.truncate()
    logger.info("completed preprocessing for collection %s", collection_id)
    return csv_files
