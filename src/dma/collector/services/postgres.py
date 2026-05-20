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
"""PostgreSQL collection service using SQLSpec ADBC.

This module provides the PostgreSQL-specific collection service that uses
ADBC for zero-copy Arrow data transfer from PostgreSQL to DuckDB.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from rich.padding import Padding
from sqlspec.exceptions import OperationalError, SQLSpecError

from dma.cli._utils import console
from dma.collector.util.postgres.helpers import get_db_major_version
from dma.lib.db.manager import get_available_queries, get_sql
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    import pyarrow as pa
    from sqlspec.adapters.adbc import AdbcDriver


class PostgresCollectionService:
    """PostgreSQL collection service using SQLSpec ADBC.

    This service encapsulates all PostgreSQL data collection logic, using
    ADBC for efficient data transfer. It provides version-aware query
    selection and high-level methods for each collection operation.
    """

    def __init__(
        self,
        driver: "AdbcDriver",
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
    ) -> None:
        """Initialize the PostgreSQL collection service.

        Args:
            driver: SQLSpec ADBC driver instance.
            execution_id: Unique execution identifier.
            source_id: Source database identifier.
            manual_id: Manual collection identifier.
        """
        self.driver = driver
        self.execution_id = execution_id
        self.source_id = source_id
        self.manual_id = manual_id
        self.db_version: str | None = None

    def get_db_version(self) -> str:
        """Get the database version.

        Returns:
            The database version string.

        Raises:
            ApplicationError: If version was not set during initialization.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        return self.db_version

    def set_identifiers(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        db_version: str | None = None,
    ) -> None:
        """Set collection identifiers, running init queries if needed.

        Args:
            execution_id: Unique execution identifier.
            source_id: Source database identifier.
            manual_id: Manual collection identifier.
            db_version: Database version string.
        """
        if execution_id is not None:
            self.execution_id = execution_id
        if source_id is not None:
            self.source_id = source_id
        if manual_id is not None:
            self.manual_id = manual_id
        if db_version is not None:
            self.db_version = db_version

        if self.execution_id is None or self.source_id is None or self.db_version is None:
            init_results = self.execute_init_queries()
            self.source_id = source_id if source_id is not None else init_results.get("init_get_source_id")
            self.execution_id = execution_id if execution_id is not None else init_results.get("init_get_execution_id")
            self.db_version = db_version if db_version is not None else init_results.get("init_get_db_version")

        if self.source_id is None or self.execution_id is None or self.db_version is None:
            msg = "Failed to set execution identifiers for collection."
            raise ApplicationError(msg)

    def execute_init_queries(self) -> dict[str, Any]:
        """Execute initialization queries to get db version and identifiers.

        Returns:
            Dictionary mapping query names to their scalar results.
        """
        console.print(Padding("SCRIPT INITIALIZATION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in get_available_queries("postgres_init"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                result = self.driver.select_value(get_sql(script).sql)
                # Store with unprefixed key for backwards compatibility
                key = script.replace("postgres_", "")
                results[key] = result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not get_available_queries("postgres_init"):
                status.console.print(
                    " [dim grey]:heavy_check_mark: No initialization queries for this database type[/]"
                )
            return results

    def get_collection_queries(self) -> set[str]:
        """Get the set of collection query names for the current PostgreSQL version.

        Returns:
            Set of query names to execute for collection.

        Raises:
            ApplicationError: If database version was not set.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        major_version = get_db_major_version(self.db_version)
        version_prefix = "base" if major_version > 13 else "13" if major_version == 13 else "12"
        bg_writer_stats = (
            "collection-postgres-bg-writer-stats"
            if major_version < 17
            else "collection-postgres-bg-writer-stats-from-pg17"
        )
        return {
            f"collection-postgres-{version_prefix}-table-details",
            f"collection-postgres-{version_prefix}-database-details",
            f"collection-postgres-{version_prefix}-replication-slots",
            "collection-postgres-applications",
            "collection-postgres-aws-extension-dependency",
            "collection-postgres-aws-oracle-exists",
            bg_writer_stats,
            "collection-postgres-calculated-metrics",
            "collection-postgres-data-types",
            "collection-postgres-index-details",
            "collection-postgres-replication-stats",
            "collection-postgres-schema-details",
            "collection-postgres-schema-objects",
            "collection-postgres-settings",
            "collection-postgres-source-details",
            "collection-postgres-replication-role",
        }

    def get_extended_collection_queries(self) -> set[str]:
        """Get the set of extended collection query names.

        Returns:
            Set of extended collection query names.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        return set(get_available_queries("extended_collection"))

    def get_per_db_collection_queries(self) -> set[str]:
        """Get collection queries that need to run for each database.

        Returns:
            Set of per-database query names.

        Raises:
            ApplicationError: If database version was not set.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        return {
            "collection-postgres-extensions",
            "collection-postgres-pglogical-provider-node",
            "collection-postgres-pglogical-privileges",
            "collection-postgres-pglogical-schema-usage-privilege",
            "collection-postgres-user-schemas-without-privilege",
            "collection-postgres-user-tables-without-privilege",
            "collection-postgres-user-views-without-privilege",
            "collection-postgres-user-sequences-without-privilege",
            "collection-postgres-tables-with-no-primary-key",
            "collection-postgres-tables-with-primary-key-replica-identity",
        }

    def execute_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
    ) -> "dict[str, pa.Table]":
        """Execute main collection queries.

        Uses ADBC's zero-copy Arrow transfer for efficient data collection.

        Args:
            execution_id: Override execution identifier.
            source_id: Override source identifier.
            manual_id: Override manual identifier.

        Returns:
            Dictionary mapping table names to Arrow tables.
        """
        self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("COLLECTION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, pa.Table] = {}
            for script in self.get_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                arrow_result = self.driver.select_to_arrow(
                    get_sql(script).sql,
                    PKEY=self.execution_id,
                    DMA_SOURCE_ID=self.source_id,
                    DMA_MANUAL_ID=self.manual_id,
                )
                # Convert query name: hyphens to underscores for table name compatibility
                table_name = script.replace("-", "_")
                results[table_name] = arrow_result.data
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.get_collection_queries():
                status.console.print(" [dim grey]:heavy_check_mark: No collection queries for this database type[/]")
            return results

    def execute_extended_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
    ) -> "dict[str, pa.Table]":
        """Execute extended collection queries.

        Uses ADBC's zero-copy Arrow transfer for efficient data collection.

        Args:
            execution_id: Override execution identifier.
            source_id: Override source identifier.
            manual_id: Override manual identifier.

        Returns:
            Dictionary mapping table names to Arrow tables.
        """
        self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("EXTENDED COLLECTION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, pa.Table] = {}
            for script in self.get_extended_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                arrow_result = self.driver.select_to_arrow(
                    get_sql(script).sql,
                    PKEY=self.execution_id,
                    DMA_SOURCE_ID=self.source_id,
                    DMA_MANUAL_ID=self.manual_id,
                )
                table_name = script.replace("-", "_")
                results[table_name] = arrow_result.data
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.get_extended_collection_queries():
                console.print(" [dim grey]:heavy_check_mark: No extended collection queries for this database type[/]")
            return results

    def execute_per_db_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
    ) -> "dict[str, pa.Table]":
        """Execute per-database collection queries.

        Uses ADBC's zero-copy Arrow transfer for efficient data collection.

        Args:
            execution_id: Override execution identifier.
            source_id: Override source identifier.
            manual_id: Override manual identifier.

        Returns:
            Dictionary mapping table names to Arrow tables.
        """
        self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("PER DB QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, pa.Table] = {}
            for script in self.get_per_db_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                try:
                    arrow_result = self.driver.select_to_arrow(
                        get_sql(script).sql,
                        PKEY=self.execution_id,
                        DMA_SOURCE_ID=self.source_id,
                        DMA_MANUAL_ID=self.manual_id,
                    )
                    table_name = script.replace("-", "_")
                    results[table_name] = arrow_result.data
                    status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
                except (SQLSpecError, OperationalError, RuntimeError) as e:
                    # Handle database errors gracefully - skip queries for missing tables/privileges
                    error_msg = str(e).lower()
                    if any(
                        pattern in error_msg
                        for pattern in [
                            "does not exist",
                            "undefined",
                            "permission denied",
                            "insufficient privilege",
                            "unreachable",
                        ]
                    ):
                        status.console.print(
                            rf"[yellow]Skipped[/] `{script}` - required objects not available or insufficient privileges"
                        )
                    else:
                        raise
            if not self.get_per_db_collection_queries():
                status.console.print(
                    " [dim grey]:heavy_check_mark: No DB specific collection queries for this database type[/]"
                )
            return results

    def get_collection_filenames(self) -> dict[str, str]:
        """Get mapping of table names to output CSV filenames.

        Returns:
            Dictionary mapping table names to output file base names.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        major_version = get_db_major_version(self.db_version)
        version_prefix = "base" if major_version > 13 else "13" if major_version == 13 else "12"
        return {
            f"collection_postgres_{version_prefix}_table_details": "postgres_table_details",
            f"collection_postgres_{version_prefix}_database_details": "postgres_database_details",
            f"collection_postgres_{version_prefix}_replication_slots": "postgres_replication_slots",
            "collection_postgres_applications": "postgres_applications",
            "collection_postgres_aws_extension_dependency": "postgres_aws_extension_dependency",
            "collection_postgres_aws_oracle_exists": "postgres_aws_oracle_exists",
            "collection_postgres_bg_writer_stats": "postgres_bg_writer_stats",
            "collection_postgres_bg_writer_stats_from_pg17": "postgres_bg_writer_stats_from_pg17",
            "collection_postgres_calculated_metrics": "postgres_calculated_metrics",
            "collection_postgres_data_types": "postgres_data_types",
            "collection_postgres_extensions": "postgres_extensions",
            "collection_postgres_index_details": "postgres_index_details",
            "collection_postgres_replication_stats": "postgres_replication_stats",
            "collection_postgres_schema_details": "postgres_schema_details",
            "collection_postgres_schema_objects": "postgres_schema_objects",
            "collection_postgres_settings": "postgres_settings",
            "collection_postgres_source_details": "postgres_source_details",
            "collection_postgres_pglogical_provider_node": "postgres_pglogical_details",
            "collection_postgres_tables_with_no_primary_key": "postgres_table_details",
            "collection_postgres_tables_with_primary_key_replica_identity": "postgres_table_details",
            "collection_postgres_replication_role": "collection_privileges",
        }
