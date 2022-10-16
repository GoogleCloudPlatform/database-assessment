from typing import TYPE_CHECKING

import duckdb

from dbma import log, storage
from dbma.config import settings
from dbma.utils import file_helpers as helpers

if TYPE_CHECKING:
    from pathlib import Path

    from duckdb import DuckDBPyConnection
    from pyarrow.lib import Table as ArrowTable

__all__ = [
    "CSVTransformer",
]

logger = log.get_logger()


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
        storage.engine.fs.auto_mkdir = True
        if self.file_path and self.file_path.stat().st_size > 0:

            file = f"{self.file_path.parent}/{self.file_path.stem}.parquet"
            # nosec
            query = f"""
            --begin-sql
                COPY (
                select * from read_csv_auto(?, delim = ?, header = ?, normalize_names=true, ignore_errors=true)
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
            storage.engine.fs.put(
                file,
                f"{settings.collections_path}/processed/{self.collection_id}/{self.file_path.stem}.parquet",
            )

    def to_df(self) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.df()

    def _select_data(self) -> "DuckDBPyConnection":
        """Select the data from the CSV"""
        results = self.local_db.execute(
            """
            --begin-sql
            select * from read_csv_auto(?, delim = ?, header = ?, normalize_names=true, ignore_errors=true)
            --end-sql
            """,
            [str(self.file_path), self.delimiter, self.has_headers],
        )
        return results
