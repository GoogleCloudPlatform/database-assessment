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
from __future__ import annotations

import faulthandler
import functools as ft
from typing import TYPE_CHECKING, Any

import aiosql as sql
from aiosql.adapters.duckdb import DuckDBAdapter

from dma.cli._utils import console

faulthandler.enable()
if TYPE_CHECKING:
    from collections.abc import Callable

    from aiosql.queries import Queries
    from duckdb import DuckDBPyConnection


class QueryManager:
    """Stores the queries for a version of the collection."""

    def __init__(self, local_db: DuckDBPyConnection, sql_file_paths: str | list[str]) -> None:
        """Query Manager.

        Args:
            local_db (DuckDBPyConnection): local DuckDB connection
            sql_file_paths (str | list[str]): _description_
        """
        self.local_db = local_db
        self.sql_file_paths = [sql_file_paths] if isinstance(sql_file_paths, str) else sql_file_paths
        self._queries: list[Queries] = []
        self._count: dict[str, int] = {}
        self._available_queries: set[str] = set()
        for sql_path in self.sql_file_paths:
            self.add_sql_from_path(sql_path)

    def add_sql_from_path(self, fn: str) -> None:
        """Load queries from a file or directory."""
        self._create_fns(sql.from_path(fn, driver_adapter=DuckDBAdapter))

    def add_sql_from_str(self, qs: str) -> None:
        """Load queries from a string."""
        self._create_fns(sql.from_str(qs, driver_adapter=DuckDBAdapter))

    def get_table_columns(self, table_name: str) -> list[str]:
        """Return a list of columns for the canonical table"""
        return [_.upper() for _ in self.local_db.table(table_name).columns]

    def get_csv_file_columns(self, csv_file_name: str, csv_header: bool) -> list[str]:
        """Return a list of columns for the CSV file"""
        return [_.upper() for _ in self.local_db.read_csv(csv_file_name, header=csv_header, sample_size=1).columns]

    def get_parquet_file_columns(self, parquet_file_name: str) -> list[str]:
        """Return a list of columns for the Parquet file"""
        return [_[0].upper() for _ in self.local_db.sql(f"DESCRIBE SELECT * FROM '{parquet_file_name}'").fetchall()]  # noqa: S608

    def csv_has_header(self, csv_file_name: str, header_first_columns: list[str]) -> bool:
        """Detect if CSV file has header by comparing the first column name with a list of expected names"""
        return self.local_db.read_csv(csv_file_name, header=True, sample_size=1).columns[0] in header_first_columns

    def get_csv_rowcount(self, csv_file_name: str, csv_header: bool) -> int:
        """Return the CSV row count"""
        relation = self.local_db.read_csv(csv_file_name, header=csv_header, sample_size=1)
        result = relation.count(f"{relation.columns[0]}").fetchone()
        return int(result[0]) if result else -1

    @property
    def collection_queries(self) -> list[str]:
        """Get transformation scripts."""
        return sorted([q for q in self._available_queries if q.startswith("collection")])

    @property
    def extended_collection_queries(self) -> list[str]:
        """Get load scripts."""
        return sorted([q for q in self._available_queries if q.startswith("extended-collection")])

    def execute_collection_queries(self, *args: Any, **kwargs: Any) -> None:
        """Execute pre-processing queries."""
        console.print("executing collection queries")
        for script in self.collection_queries:
            console.print(f".. executing collection query {script}")
            getattr(self, script)()

    def execute_extended_collection_queries(self) -> None:
        """Execute extended collection queries.

        Returns: None
        """
        console.print("executing extended collection queries")

        for script in self.extended_collection_queries:
            fn = getattr(self, script)
            console.print(f".. executing extended collection query {script}")

            fn()

    def _call_fn(self, query: str, fn: Callable, *args: Any, **kwargs: Any) -> Any:
        """Forward method call to aiosql query."""
        self._count[query] += 1
        return fn(self.local_db, *args, **kwargs)

    def _create_fns(self, queries: Queries) -> None:
        """Create call forwarding to insert the database connection."""
        self._queries.append(queries)
        for q in queries.available_queries:
            f = getattr(queries, q)
            # we skip internal *_cursor attributes
            if callable(f):
                setattr(self, q, ft.partial(self._call_fn, q, f))
                self._available_queries.add(q)
                self._count[q] = 0

    def __str__(self) -> str:
        """Return Query Manager as a string."""
        return f"Query Manager for ({self.sql_file_paths})"
