from __future__ import annotations

from typing import TYPE_CHECKING, Literal

import polars as pl

if TYPE_CHECKING:
    from pathlib import Path

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

    async def execute(self) -> None:
        """Execute Workflow"""
        await self.canonical_query_manager.execute_ddl_scripts()

    def import_to_table(self, data: dict[str, list[dict]]) -> None:
        """Load a dictionary of result sets into duckdb.

        The key of the dictionary becomes the table name in the database.
        """
        for table_name, table_data in data.items():
            if len(table_data) > 0:
                column_names = table_data[0].keys()
                self.local_db.register(
                    f"obj_{table_name}", pl.from_dicts(table_data, strict=False, infer_schema_length=10000)
                )
                self.local_db.execute(
                    f"insert into {table_name}({", ".join(column_name for column_name in column_names)}) select {", ".join(column_name for column_name in column_names)} from obj_{table_name}"  # noqa: S608
                )
                self.local_db.execute(f"drop view obj_{table_name}")

    def dump_database(self, export_path: Path, delimiter: str = "|") -> None:
        """Export the entire database with DDLs and data as CSV"""
        self.local_db.execute(f"export database '{export_path!s}' (format csv, delimiter '{delimiter}')")
