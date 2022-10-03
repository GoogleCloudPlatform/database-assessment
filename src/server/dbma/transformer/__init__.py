from tempfile import TemporaryDirectory
from typing import TYPE_CHECKING, Generator, Optional

from pydantic import ValidationError

from dbma import log
from dbma.db import SQLManager
from dbma.transformer.helpers import extract_collection, identify_collection_version_from_name
from dbma.transformer.schemas.base import CollectionArchive
from dbma.transformer.version_maps import get_config_for_version

__all__ = ["process_collection"]

if TYPE_CHECKING:
    from pathlib import Path


logger = log.get_logger()


def get_temp_dir() -> Generator[TemporaryDirectory, None, None]:
    with TemporaryDirectory() as d:
        yield d  # type: ignore


def process_collection(
    collections: list["Path"], extract_path: "TemporaryDirectory | Path", parse_as_version: Optional[str] = None
) -> None:
    """Process the collection"""
    # override or detect version to process with
    if parse_as_version:
        logger.info("=> Skipping version analysis and forcing version to be %s", parse_as_version)
    else:
        logger.info("=> Detecting collector version")
    valid_collections = extract_and_validate_archive(collections, extract_path, parse_as_version)
    if len(valid_collections) == 0:
        raise FileNotFoundError("No collections found to process")
    # loop through the collections that were successfully extracted
    for collection in valid_collections:
        sql = SQLManager(engine_type="duckdb", sql_files_path=str(collection.config.sql_files_path))
        files_to_load: "dict[str, Path]" = collection.files.dict(exclude_none=True)
        for file_type, file_name in files_to_load.items():
            if file_name.stat().st_size > 0:
                logger.info(sql.read_csv(str(file_name)))
            else:
                logger.info("skipping the load of empty file: %s", file_type)


def extract_and_validate_archive(
    collections: list["Path"], extract_path: "TemporaryDirectory | Path", parse_as_version: Optional[str] = None
) -> list["CollectionArchive"]:
    """Process the collection"""
    # override or detect version to process with
    if parse_as_version:
        logger.info("=> Skipping version analysis and forcing version to be %s", parse_as_version)
    else:
        logger.info("=> Detecting collector version")
    valid_collections: "list[CollectionArchive]" = []
    # loop through collections and extract them
    for extract in collections:
        version = parse_as_version or identify_collection_version_from_name(extract.stem)
        config = get_config_for_version(version)
        logger.info('=> config specifies the "%s" character as the delimiter', config.delimiter)
        files = extract_collection(extract, extract_path)
        try:
            valid_collections.append(
                CollectionArchive.parse_obj({"config": config, "files": config.collection_schema.from_file_list(files)})
            )
        except ValidationError as e:
            logger.error("failed to validate files contained in collections: %s", e.errors)
            raise e from e
    return valid_collections
