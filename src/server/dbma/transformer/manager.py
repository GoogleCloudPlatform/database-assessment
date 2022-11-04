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
import functools as ft
from typing import TYPE_CHECKING, Any, Callable, Dict, List, Set

import aiosql as sql

from dbma import log
from dbma.utils.aiosql_adapters import DuckDBAdapter

if TYPE_CHECKING:

    from aiosql.queries import Queries
    from duckdb import DuckDBPyConnection

    from dbma.transformer.schemas import Collection

__all__ = ["SQLManager"]


logger = log.get_logger()


class SQLManager:
    """Stores the queries for a version of the collection"""

    def __init__(self, db: "DuckDBPyConnection", sql_files_path: str, canonical_path: str) -> None:

        self.db = db
        self.sql_files_path = sql_files_path
        self._queries: "List[Queries]" = []
        self._count: Dict[str, int] = {}
        self._available_queries: Set[str] = set()
        self.add_sql_from_path(canonical_path)
        self.add_sql_from_path(sql_files_path)

    def add_sql_from_path(self, fn: str) -> None:
        """Load queries from a file or directory."""
        self._create_fns(sql.from_path(fn, driver_adapter=DuckDBAdapter))

    def add_sql_from_str(self, qs: str) -> None:
        """Load queries from a string."""
        self._create_fns(sql.from_str(qs, driver_adapter=DuckDBAdapter))

    @property
    def transformation_scripts(self) -> list[str]:
        """Get transformation scripts"""
        return sorted([q for q in self._available_queries if q.startswith("transform")])

    def execute_transformation_scripts(self) -> None:
        """


        Returns:
            _type_: _description_
        """
        for script in self.transformation_scripts:
            fn = getattr(self, script)
            logger.info("executing transformation script %s", script)
            fn()

    @property
    def load_scripts(self) -> list[str]:
        """Get transformation scripts"""
        return sorted([q for q in self._available_queries if q.startswith("load")])

    def execute_load_scripts(self, collection: "Collection") -> None:
        """Execute load scripts

        Accepts a collection and runs the SQL load scripts against it.

        Args:
            collection (Collection): The collection of Advisor extract files
        """
        for file_type, file_name in collection.files.dict(exclude_unset=True, exclude_none=True).items():
            logger.debug("delimiter is %s", collection.files.delimiter)
            has_load_fn = hasattr(self, f"load_{file_type}")
            if not has_load_fn:
                logger.warning("... [bold yellow] Could not find a load procedure for %s.", file_type)
            if file_name.stat().st_size > 0:
                fn = getattr(self, f"load_{file_type}")
                rows_loaded = fn(str(file_name.absolute()), collection.files.delimiter)
                logger.info("... %s  [green bold]SUCCESS[/] [%s rows(s)]", file_type, rows_loaded)

            else:
                logger.info("... %s  [dim bold]SKIPPED[/] [empty file]", file_type)

    @property
    def pre_processing_scripts(self) -> list[str]:
        """Get transformation scripts

        Returns a sorted list of available commands loaded from the SQL files

        """
        return sorted([q for q in self._available_queries if q.startswith("pre")])

    def execute_pre_processing_scripts(self) -> None:
        """


        Returns:
            _type_: _description_
        """
        for script in self.pre_processing_scripts:
            logger.info("executing preprocessing script %s", script)
            getattr(self, script)()
        self.db.commit()

    def _call_fn(self, query: str, fn: Callable, *args: Any, **kwargs: Any) -> Any:
        """Forward method call to aiosql query"""
        self._count[query] += 1
        return fn(self.db, *args, **kwargs)

    def _create_fns(self, queries: "Queries") -> None:
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
        return f"Query Manager for ({self.sql_files_path})"
