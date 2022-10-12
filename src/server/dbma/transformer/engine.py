# nosec: B608
from tempfile import TemporaryDirectory
from typing import TYPE_CHECKING, Union

import duckdb
from packaging.version import LegacyVersion, Version
from pydantic import ValidationError

from dbma import db, log, storage
from dbma.transformer import helpers, schemas

if TYPE_CHECKING:

    from pathlib import Path

    from duckdb import DuckDBPyConnection
    from pyarrow.lib import Table as ArrowTable

__all__ = [
    "CSVTransformer",
    "run",
]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


class CSVTransformer:
    """Transforms a CSV to various formats"""

    def __init__(self, file_path: "Path", delimiter: str = "|", has_headers: bool = True, skip_rows: int = 0) -> None:
        self.file_path = file_path
        self.delimiter = delimiter
        self.has_headers = has_headers
        self.skip_rows = skip_rows
        self.local_db = duckdb.connect()
        self.script_version = helpers.get_version_from_file(file_path)
        self.db_version = helpers.get_db_version_from_file(file_path)
        self.collection_key = helpers.get_collection_key_from_file(file_path)
        self.collection_id = helpers.get_collection_id_from_key(self.collection_key)

    def to_arrow_table(self, chunk_size: int = 1000000) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.arrow(chunk_size)

    def to_parquet(self, output_path: str) -> None:
        """Converts the CSV to an arrow table"""
        file = f"{self.file_path.parent}/{self.file_path.stem}.parquet"
        # nosec
        query = f"""
        --begin-sql
            COPY (
            select * from read_csv_auto(?, delim = ?, header = ?)
            ) TO '{file}' (FORMAT 'parquet')
        --end-sql
        """
        self.local_db.execute(
            query,
            [
                str(self.file_path),
                self.delimiter,
                self.has_headers,
            ],
        )
        storage.engine.fs.put(file, output_path)

    def to_df(self) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.df()

    def _select_data(self) -> "DuckDBPyConnection":
        """Select the data from the CSV"""
        results = self.local_db.execute(
            """
            --begin-sql
            select * from read_csv_auto(?, delim = ?, header = ?)
            --end-sql
            """,
            [str(self.file_path), self.delimiter, self.has_headers],
        )
        return results


def run(collections: list["Path"], extract_path: "Union[TemporaryDirectory , Path]", parse_as_version: str) -> None:
    """Process the collection"""
    config = schemas.get_config_for_version(parse_as_version)
    extracted_archives: list[schemas.CollectionArchive] = extract_and_validate_archives(
        collections, extract_path, config
    )

    if len(extracted_archives) == 0:
        raise FileNotFoundError("No collections found to process")
    # loop through the collections that were successfully extracted
    sql = db.SQLManager(engine_type="duckdb", sql_files_path=str(config.sql_files_path))
    sql.execute_pre_processing_scripts()
    # sql.execute_load_scripts()

    for archive in extracted_archives:
        sql.execute_transformation_scripts(archive.files)
    rows = sql.get_database_metrics()  # type: ignore[attr-defined]
    # sql.process_collection()  # type: ignore[attr-defined]
    # rows = sql.select_table()  # type: ignore[attr-defined]

    logger.info(rows)


def extract_and_validate_archives(
    collection_archives: list["Path"],
    extract_path: "Union[TemporaryDirectory , Path]",
    config: "schemas.CollectionConfig",
) -> "list[schemas.CollectionArchive]":
    """Process the collection"""
    # override or detect version to process with
    valid_collections: "list[schemas.CollectionArchive]" = []
    # loop through collections and extract them
    for extract in collection_archives:
        detected_version = helpers.get_version_from_file(extract)
        collection_key = helpers.get_collection_key_from_file(extract)
        collection_id = helpers.get_collection_id_from_key(collection_key)
        logger.info('ℹ️  detected version "%s" from the collection name', detected_version)

        logger.debug('ℹ️  config specifies the "%s" character as the delimiter', config.delimiter)
        files = helpers.extract_collection(collection_id, extract, extract_path)
        try:
            valid_collections.append(
                schemas.CollectionArchive.parse_obj(
                    {"config": config, "files": config.collection_schema.from_file_list(files)}
                )
            )
        except ValidationError as e:
            logger.error("⚠️ [bold red]failed to validate files contained in collections: %s", e.errors)
            raise e from e
    return valid_collections
