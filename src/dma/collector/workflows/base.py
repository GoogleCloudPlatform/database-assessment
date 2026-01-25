# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Base workflow for DuckDB data processing using SQLSpec."""

from __future__ import annotations

from typing import TYPE_CHECKING, Literal

from dma.collector.util import CollectionFileWriter

if TYPE_CHECKING:
    from pathlib import Path

    import pyarrow as pa
    from rich.console import Console
    from sqlspec.adapters.duckdb import DuckDBDriver

    from dma.collector.query_managers.base import CanonicalQueryManager


class BaseWorkflow:
    """A collection of tasks that interact with DuckDB via SQLSpec driver."""

    def __init__(
        self,
        driver: "DuckDBDriver",
        canonical_query_manager: CanonicalQueryManager,
        db_type: Literal["POSTGRES"],
        console: Console,
    ) -> None:
        """Initialize a workflow with a SQLSpec DuckDB driver.

        Args:
            driver: SQLSpec DuckDB driver for database operations.
            canonical_query_manager: Manager for canonical DuckDB queries.
            db_type: Source database type (currently only POSTGRES).
            console: Rich console for output.
        """
        self.driver = driver
        self.console = console
        self.db_type = db_type
        self.canonical_query_manager = canonical_query_manager

    def execute(self) -> None:
        """Execute Workflow"""
        self.canonical_query_manager.execute_ddl_scripts()

    def import_to_table(self, data: "dict[str, pa.Table]") -> None:
        """Load Arrow tables into DuckDB via zero-copy transfer.

        The key of the dictionary becomes the table name in the database.
        Uses SQLSpec's load_from_arrow for efficient Arrow data transfer.

        Args:
            data: Dictionary mapping table names to Arrow tables.
        """
        for table_name, arrow_table in data.items():
            if arrow_table.num_rows > 0:
                self.driver.load_from_arrow(table_name, arrow_table)

    def dump_database(self, export_path: "Path", delimiter: str = "|") -> None:
        """Export the entire database with DDLs and data as CSV.

        Args:
            export_path: Directory path for exported files.
            delimiter: CSV delimiter character.
        """
        self.driver.execute(f"EXPORT DATABASE '{export_path!s}' (FORMAT CSV, DELIMITER '{delimiter}')")
        self.console.print(f"Database exported to '{export_path!s}'")

    def generate_collection_zip(
        self,
        output_dir: "Path",
        db_version: str = "",
        dma_version: str = "4.3.45",
        hostname: str = "localhost",
        port: int = 5432,
        database: str = "postgres",
    ) -> "Path":
        """Generate a collection ZIP file compatible with shell script output.

        Creates a ZIP archive containing CSV exports of all collection tables,
        a manifest file with MD5 checksums, and metadata files. The output
        format matches the shell script collector for compatibility with
        downstream processing tools.

        Args:
            output_dir: Directory for output ZIP file.
            db_version: Source database version number (e.g., "150000").
            dma_version: DMA collector version string.
            hostname: Source database hostname.
            port: Source database port.
            database: Source database name.

        Returns:
            Path to created ZIP file.
        """
        writer = CollectionFileWriter(
            driver=self.driver,
            db_type=self.db_type,
            db_version=db_version,
            dma_version=dma_version,
            hostname=hostname,
            port=port,
            database=database,
        )
        zip_path = writer.create_collection_zip(output_dir)
        self.console.print(f"Collection ZIP created: {zip_path}")
        return zip_path
