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
from typing import TYPE_CHECKING

import duckdb

from dbma import log, storage
from dbma.utils import file_helpers as helpers

if TYPE_CHECKING:
    from pathlib import Path

    from duckdb import DuckDBPyConnection
    from pandas import DataFrame
    from pyarrow.lib import Table as ArrowTable

__all__ = [
    "CSVTransformer",
]

logger = log.get_logger()


class CSVTransformer:
    """Transforms a CSV to various formats"""

    def __init__(
        self, file_path: "Path", schema_type: str, delimiter: str = "|", has_headers: bool = True, skip_rows: int = 0
    ) -> None:
        self.file_path = file_path
        self.delimiter = delimiter
        self.has_headers = has_headers
        self.skip_rows = skip_rows
        self.local_db = duckdb.connect()
        self.script_version = helpers.get_version_from_file(file_path)
        self.db_version = helpers.get_db_version_from_file(file_path)
        self.collection_key = helpers.get_collection_key_from_file(file_path)
        self.collection_id = helpers.get_collection_id_from_key(self.collection_key)
        self.schema_type = schema_type

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
                f"{output_path}/processed/{self.collection_id}/{self.schema_type}.parquet",
            )

    def to_df(self) -> "DataFrame":
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
