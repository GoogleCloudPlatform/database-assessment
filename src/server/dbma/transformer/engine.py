# nosec: B608
import re
import tarfile as tf
import zipfile as zf
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Union

from packaging.version import LegacyVersion, Version
from pydantic import ValidationError

from dbma import database, log
from dbma.config import settings
from dbma.transformer import schemas
from dbma.transformer.loaders import CSVTransformer
from dbma.utils import file_helpers

__all__ = [
    "run",
    "find_advisor_extracts_in_path",
]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


def run(
    collections: list["Path"], local_working_path: "Union[TemporaryDirectory , Path]", parse_as_version: str
) -> None:
    """Process the collection"""
    db = database.ConnectionManager(engine_type="duckdb")
    advisor_extracts: list[schemas.AdvisorExtract] = find_advisor_extracts_in_path(collections, local_working_path, db)

    if len(advisor_extracts) == 0:
        raise FileNotFoundError("No collections found to process")

    for advisor_extract in advisor_extracts:
        # sql = database.SQLManager(db, advisor_extract.config.sql_files_path)
        for file_type in advisor_extract.files.__fields__:
            file_name = getattr(advisor_extract.files, file_type)
            csv = CSVTransformer(file_path=file_name, delimiter=advisor_extract.files.delimiter)
            csv.to_parquet(settings.collections_path)
    # for advisor_extract in advisor_extracts:
    #     sql.execute_transformation_scripts(advisor_extract)
    #     sql.execute_load_scripts(advisor_extract)
    # rows = sql.get_database_metrics()  # type: ignore[attr-defined]
    # sql.process_collection()  # type: ignore[attr-defined]
    # rows = sql.select_table()  # type: ignore[attr-defined]

    # logger.info(rows)


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
        script_version = file_helpers.get_version_from_file(extract)
        version_config = schemas.get_config_for_version(str(script_version))
        db_version = file_helpers.get_db_version_from_file(extract)
        collection_key = file_helpers.get_collection_key_from_file(extract)
        collection_id = file_helpers.get_collection_id_from_key(collection_key)

        logger.info('ℹ️  detected version "%s" from the collection name', script_version)
        logger.info('ℹ️  config specifies the "%s" character as the delimiter', version_config.delimiter)
        files = extract_collection(collection_id, extract, extract_path)
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


def extract_collection(
    collection_id: str, collection_archive: "Path", extract_path: "Union[TemporaryDirectory,Path]"
) -> "list[Path]":
    """Extracts the specified collection to the specified directory.

    *Note* - This function will also rename files with a *.log to a *.csv extension.
    2.X.X versions of the collector scripts used this convention

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
    for file_to_rename in list(Path(str(extract_path)).glob(f"*{collection_id}.log")):
        new_path = file_to_rename.rename(f"{file_to_rename.parent}/{file_to_rename.stem}.csv")
        logger.info("changed file extension to csv: %s", new_path.stem)
    csv_files = list(Path(str(extract_path)).glob(f"*{collection_id}.csv"))

    for csv_file in csv_files:

        with open(csv_file, "r+", encoding="utf8") as f:
            content = f.readlines()
            f.seek(0)
            for line in content:
                if line.strip() != "" and not re.match(r"^Elapsed: (\d+):(\d+):(\d+).(\d+)$", line):
                    f.write(line)
            f.truncate()
    return csv_files
