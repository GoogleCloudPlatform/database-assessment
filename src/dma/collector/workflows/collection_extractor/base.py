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
"""Collection extractor workflow using SQLSpec ADBC.

This module provides the main collection workflow that extracts data from
source databases using SQLSpec ADBC for zero-copy Arrow data transfer.
"""

from __future__ import annotations

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from rich.table import Table

from dma.__about__ import __version__ as current_version
from dma.collector.services.postgres import PostgresCollectionService
from dma.collector.workflows.base import BaseWorkflow
from dma.collector.workflows.collection_extractor._postgres import print_summary_postgres
from dma.lib.db.config import SourceInfo, create_postgres_adbc_config
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from rich.console import Console
    from sqlspec.adapters.duckdb import DuckDBDriver

    from dma.collector.query_managers.base import CanonicalQueryManager


class CollectionExtractor(BaseWorkflow):
    """Collection extractor workflow.

    Orchestrates the full data collection process from source databases
    to DuckDB using SQLSpec for database connectivity.
    """

    def __init__(
        self,
        driver: "DuckDBDriver",
        src_info: SourceInfo,
        database: str,
        canonical_query_manager: CanonicalQueryManager,
        console: Console,
        collection_identifier: str | None,
    ) -> None:
        """Initialize the collection extractor.

        Args:
            driver: SQLSpec DuckDB driver for local data storage.
            src_info: Source database connection information.
            database: Target database name.
            canonical_query_manager: Manager for canonical DuckDB queries.
            console: Rich console for output.
            collection_identifier: Optional manual collection identifier.
        """
        self.src_info = src_info
        self.database = database
        self.collection_identifier = collection_identifier
        self.db_version: str | None = None
        super().__init__(driver, canonical_query_manager, src_info.db_type, console)

    def execute(self) -> None:
        """Execute the full collection workflow."""
        super().execute()
        execution_id = (
            f"{self.src_info.db_type}_{current_version!s}_{datetime.now(tz=timezone.utc).strftime('%y%m%d%H%M%S')}"
        )
        self.collect_data(execution_id)
        self.collect_db_specific_data(execution_id)

    def collect_data(self, execution_id: str) -> None:
        """Collect main data from the source database.

        Uses SQLSpec ADBC for PostgreSQL to enable zero-copy Arrow
        data transfer.

        Args:
            execution_id: Unique execution identifier.
        """
        if self.src_info.db_type == "POSTGRES":
            self._collect_postgres_data(execution_id)
        else:
            msg = f"{self.src_info.db_type} collection is not yet migrated to SQLSpec."
            raise ApplicationError(msg)

    def _collect_postgres_data(self, execution_id: str) -> None:
        """Collect data from PostgreSQL using ADBC.

        Args:
            execution_id: Unique execution identifier.
        """
        config = create_postgres_adbc_config(self.src_info, self.database)

        with config.provide_session() as pg_driver:
            service = PostgresCollectionService(
                driver=pg_driver,
                execution_id=execution_id,
                manual_id=self.collection_identifier,
            )
            collection = service.execute_collection_queries()
            self.import_to_table(collection)
            extended_collection = service.execute_extended_collection_queries()
            self.import_to_table(extended_collection)
            self.process_collection()
            self.db_version = service.get_db_version()

    def collect_db_specific_data(self, execution_id: str) -> None:
        """Collect per-database data.

        Executes queries that must run against each database in the instance.

        Args:
            execution_id: Unique execution identifier.
        """
        if self.src_info.db_type != "POSTGRES":
            return

        dbs = self.get_all_dbs()
        for db in dbs:
            config = create_postgres_adbc_config(self.src_info, db)
            with config.provide_session() as pg_driver:
                service = PostgresCollectionService(
                    driver=pg_driver,
                    execution_id=execution_id,
                    manual_id=self.collection_identifier,
                )
                # Set version from main collection
                service.db_version = self.db_version
                db_collection = service.execute_per_db_collection_queries()
                self.import_to_table(db_collection)

    def get_all_dbs(self) -> set[str]:
        """Get all database names from the extended collection.

        Returns:
            Set of database names.
        """
        result = self.driver.select("select database_name from extended_collection_postgres_all_databases")
        return {row["database_name"] for row in result}

    def get_db_version(self) -> str:
        """Get the database version.

        Returns:
            Database version string.

        Raises:
            ApplicationError: If version was not set.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        return self.db_version

    def extract_collection(self, service: PostgresCollectionService) -> None:
        """Extract main collection data.

        Args:
            service: Collection service instance.
        """
        collection = service.execute_collection_queries()
        self.import_to_table(collection)

    def extract_extended_collection(self, service: PostgresCollectionService) -> None:
        """Extract extended collection data.

        Args:
            service: Collection service instance.
        """
        extended_collection = service.execute_extended_collection_queries()
        self.import_to_table(extended_collection)

    def process_collection(self) -> None:
        """Process collected data."""

    def print_summary(self) -> None:
        """Print summary of the collection."""
        table = Table(show_header=False)
        table.add_column("title", style="cyan", width=80)
        table.add_row("Collection Summary")
        self.console.print(table)
        if self.db_type == "POSTGRES":
            print_summary_postgres(console=self.console, driver=self.driver, manager=self.canonical_query_manager)
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)
