# nosec: B608
import re
import sys
import tarfile as tf
import zipfile as zf
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Any, Union

from packaging.version import LegacyVersion, Version
from pydantic import ValidationError

from dbma import database, log, storage, utils
from dbma.config import settings
from dbma.transformer import schemas
from dbma.transformer.loaders import CSVTransformer

__all__ = ["load_collection", "find_advisor_extracts_in_path", "process_collection_archives"]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


def process_collection_archives(collection: Path, collection_version: str) -> None:
    """Process a collection or set of collections"""
    logger.info("launching Collection loader against %s Google Cloud Project", settings.google_project_id)
    # setup configuration based on user input
    if collection.is_dir():
        # The path is a directory.  We need to check for zipped archives
        logger.info("🔎 Searching for collection archives in the specified directory")
        collections_to_process = (
            list(collection.glob("opdb__*.tar.gz"))
            + list(collection.glob("opdb__*.zip"))
            + list(collection.glob("opdb__*.tgz"))
        )
        if len(collections_to_process) < 1:
            logger.error("⚠️ No collection files were found in the specified directory")
            sys.exit(1)
    else:
        collections_to_process = [collection]

    # handled parsed list of collection paths
    filenames = [f"{c.stem}{c.suffix}" for c in collections_to_process]
    store_collection(collections_to_process)
    logger.debug("ℹ️  Processing %d collection(s)", len(filenames))
    logger.debug("ℹ️  Collections to process: %s", filenames)
    temp_path = settings.temp_path or next(utils.file_helpers.get_temp_dir())
    load_collection(
        files=collections_to_process,
        local_working_path=temp_path,
        parse_as_version=collection_version,
    )
    dirs = storage.engine.fs.ls(settings.collections_path)
    logger.info(dirs)


def load_collection(
    files: "list[Path]", local_working_path: "Union[TemporaryDirectory , Path]", parse_as_version: str
) -> None:
    """Load discovered collection archives

    Args:
        files (list[Path]): _description_
        local_working_path (Union[TemporaryDirectory , Path]): _description_
        parse_as_version (str): _description_

    Raises:
        FileNotFoundError: _description_
    """
    db = database.ConnectionManager(engine_type="duckdb")
    advisor_extracts: list[schemas.AdvisorExtract] = find_advisor_extracts_in_path(files, local_working_path, db)

    if len(advisor_extracts) == 0:
        raise FileNotFoundError("No collections found to process")

    for advisor_extract in advisor_extracts:
        for file_type in advisor_extract.files.__fields__:
            file_name = getattr(advisor_extract.files, file_type)
            csv = CSVTransformer(file_path=file_name, delimiter=advisor_extract.files.delimiter)
            csv.to_parquet(settings.collections_path)
        logger.info("converted all files to parquet for collection %s", advisor_extract.collection_id)
    rows: dict[str, Any] = {}
    for advisor_extract in advisor_extracts:
        # advisor_extract.queries.execute_pre_processing_scripts()
        advisor_extract.queries.execute_load_scripts(advisor_extract)
        advisor_extract.queries.execute_transformation_scripts(advisor_extract)
        logger.info(advisor_extract.queries.get_test())  # type: ignore[attr-defined]
        database_metrics = advisor_extract.queries.get_db_metrics()  # type: ignore[attr-defined]
        database_features = advisor_extract.queries.get_db_features()  # type: ignore[attr-defined]
        rows.update(
            {
                "database_metrics": rows.get("database_metrics", []) + database_metrics,
                "database_features": rows.get("database_features", []) + database_features,
            }
        )

    logger.info(rows)


def find_advisor_extracts_in_path(
    advisor_extracts: list["Path"],
    extract_path: "Union[TemporaryDirectory , Path]",
    db: "database.ConnectionManager",
) -> "list[schemas.AdvisorExtract]":
    """Process the collection"""
    # override or detect version to process with
    valid_collections: "list[schemas.AdvisorExtract]" = []
    # loop through collections and extract them
    for extract in advisor_extracts:
        script_version = utils.file_helpers.get_version_from_file(extract)
        version_config = schemas.get_config_for_version(str(script_version))
        db_version = utils.file_helpers.get_db_version_from_file(extract)
        collection_key = utils.file_helpers.get_collection_key_from_file(extract)
        collection_id = utils.file_helpers.get_collection_id_from_key(collection_key)

        logger.info('ℹ️  detected version "%s" from the collection name', script_version)
        files = parse_collection(collection_id, extract, extract_path)
        try:
            valid_collections.append(
                schemas.AdvisorExtract.parse_obj(
                    {
                        "config": schemas.get_config_for_version(str(script_version)),
                        "files": version_config.collection_files_schema.from_file_list(files),
                        "collection_id": collection_id,
                        "collection_key": collection_key,
                        "script_version": script_version,
                        "db_version": db_version,
                        "queries": database.SQLManager(db, version_config.sql_files_path),
                    }
                )
            )
        except ValidationError as e:
            logger.error("⚠️ [bold red]failed to validate files contained in collections: %s", e.errors)
            raise e from e
    return valid_collections


def parse_collection(
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


def store_collection(collections: list[Path]) -> None:
    """Store archive to storage backend"""
    for archive in collections:
        # collection_key = utils.file_helpers.get_collection_key_from_file(archive)
        # collection_id = utils.file_helpers.get_collection_id_from_key(collection_key)
        storage_path = f"{settings.collections_path}/upload/{archive.stem}{archive.suffix}"
        storage.engine.fs.mkdir(storage_path, create_parents=True)
        storage.engine.fs.put(str(archive), storage_path)
