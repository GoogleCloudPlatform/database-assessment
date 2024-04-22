from __future__ import annotations

from typing import TYPE_CHECKING, Literal

import polars as pl

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager


class BaseWorkflow:
    """A collection of tasks that interact with DuckDB"""

    def __init__(
        self,
        local_db: DuckDBPyConnection,
        canonical_query_manager: CanonicalQueryManager,
        db_type: Literal["mysql", "postgres", "mssql", "oracle"],
        console: Console,
    ) -> None:
        """Initialize a workflow on a local duckdb instance."""
        self.local_db = local_db
        self.console = console
        self.db_type = db_type
        self.canonical_query_manager = canonical_query_manager

    def import_to_table(self, data: dict[str, list[dict]]) -> None:
        """Load a dictionary of result sets into duckdb.

        The key of the dictionary becomes the table name in the database.
        """
        for table_name, table_data in data.items():
            if len(table_data) > 0:
                self.local_db.register(table_name, pl.from_dicts(table_data, infer_schema_length=10000))
