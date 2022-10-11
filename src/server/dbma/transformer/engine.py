from tempfile import TemporaryDirectory
from typing import TYPE_CHECKING, Union

from pydantic import ValidationError

from dbma import log
from dbma.db import SQLManager
from dbma.transformer.helpers import extract_collection, identify_collection_version_from_name
from dbma.transformer.schemas.base import CollectionArchive
from dbma.transformer.version_maps import get_config_for_version

__all__ = ["process"]

if TYPE_CHECKING:
    from pathlib import Path


logger = log.get_logger()


def process(collections: list["Path"], extract_path: "Union[TemporaryDirectory , Path]", parse_as_version: str) -> None:
    """Process the collection"""
    config = get_config_for_version(parse_as_version)
    extracted_archives = _extract_and_validate_archive(collections, extract_path, parse_as_version)

    if len(extracted_archives) == 0:
        raise FileNotFoundError("No collections found to process")
    # loop through the collections that were successfully extracted
    sql = SQLManager(engine_type="duckdb", sql_files_path=str(config.sql_files_path))
    sql.create_schema()  # type: ignore[attr-defined]
    sql_target = SQLManager(engine_type="bigquery", sql_files_path=str(config.sql_files_path))
    for archive in extracted_archives:

        archive.files.load(sql, archive.config.delimiter)
        transform_scripts = [
            q for q in sql._available_queries if q.startswith("transform")  # pylint: disable=[protected-access
        ]
        for transform_script in sorted(transform_scripts):
            getattr(sql, transform_script)()
        rows = sql.get_database_metrics()  # type: ignore[attr-defined]
        # sql.process_collection()  # type: ignore[attr-defined]
        # rows = sql.select_table()  # type: ignore[attr-defined]
        logger.info(rows)


def _extract_and_validate_archive(
    collections: list["Path"], extract_path: "Union[TemporaryDirectory , Path]", config: "CollectionConfig"
) -> list["CollectionArchive"]:
    """Process the collection"""
    # override or detect version to process with
    valid_collections: "list[CollectionArchive]" = []
    # loop through collections and extract them
    for extract in collections:
        detected_version = identify_collection_version_from_name(extract.stem)
        logger.debug('ℹ️  config specifies the "%s" character as the delimiter', config.delimiter)
        files = extract_collection(extract, extract_path)
        try:
            valid_collections.append(
                CollectionArchive.parse_obj({"config": config, "files": config.collection_schema.from_file_list(files)})
            )
        except ValidationError as e:
            logger.error("⚠️ [bold red]failed to validate files contained in collections: %s", e.errors)
            raise e from e
    return valid_collections
