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
"""PostgreSQL collection query manager using SQLSpec.

This module provides the PostgreSQL-specific collection query manager
that handles version-aware query selection for data collection.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from dma.collector.query_managers.base import CollectionQueryManager
from dma.collector.util.postgres.helpers import get_db_major_version
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from sqlspec.adapters.adbc import AdbcDriver


class PostgresCollectionQueryManager(CollectionQueryManager):
    """PostgreSQL collection query manager.

    Provides version-aware query selection for PostgreSQL data collection,
    supporting PostgreSQL versions 12 through 17+.
    """

    def __init__(
        self,
        driver: "AdbcDriver",
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
    ) -> None:
        """Initialize the PostgreSQL query manager.

        Args:
            driver: SQLSpec ADBC driver instance.
            execution_id: Unique execution identifier.
            source_id: Source database identifier.
            manual_id: Manual collection identifier.
        """
        super().__init__(
            driver=driver,
            execution_id=execution_id,
            source_id=source_id,
            manual_id=manual_id,
        )

    def get_collection_queries(self) -> set[str]:
        """Get version-specific collection query names.

        Returns:
            Set of query names appropriate for the PostgreSQL version.

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

    def get_per_db_collection_queries(self) -> set[str]:
        """Get per-database collection query names.

        Returns:
            Set of query names to execute for each database.

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

    def get_collection_filenames(self) -> dict[str, str]:
        """Get mapping of query names to output CSV filenames.

        Returns:
            Dictionary mapping query names to output file base names.

        Raises:
            ApplicationError: If database version was not set.
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
