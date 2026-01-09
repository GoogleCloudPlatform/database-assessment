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
from __future__ import annotations

from typing import TYPE_CHECKING, Any

import aiosql

from dma.collector.query_managers.base import CollectionQueryManager
from dma.collector.util.postgres.helpers import get_db_major_version
from dma.lib.exceptions import ApplicationError
from dma.utils import module_to_os_path

if TYPE_CHECKING:
    from aiosql.queries import Queries

_root_path = module_to_os_path("dma")


class PostgresCollectionQueryManager(CollectionQueryManager):
    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(
            sql_path=f"{_root_path}/collector/sql/sources/postgres/",
            driver_adapter="psycopg",
            mandatory_parameters=False,
        ),
    ) -> None:
        super().__init__(
            connection=connection, queries=queries, execution_id=execution_id, source_id=source_id, manual_id=manual_id
        )

    def get_collection_queries(self) -> set[str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        major_version = get_db_major_version(self.db_version)
        version_prefix = "base" if major_version > 13 else "13" if major_version == 13 else "12"
        bg_writer_stats = (
            "collection_postgres_bg_writer_stats"
            if major_version < 17
            else "collection_postgres_bg_writer_stats_from_pg17"
        )
        return {
            f"collection_postgres_{version_prefix}_table_details",
            f"collection_postgres_{version_prefix}_database_details",
            f"collection_postgres_{version_prefix}_replication_slots",
            "collection_postgres_applications",
            "collection_postgres_aws_extension_dependency",
            "collection_postgres_aws_oracle_exists",
            bg_writer_stats,
            "collection_postgres_calculated_metrics",
            "collection_postgres_data_types",
            "collection_postgres_index_details",
            "collection_postgres_replication_stats",
            "collection_postgres_schema_details",
            "collection_postgres_schema_objects",
            "collection_postgres_settings",
            "collection_postgres_source_details",
            "collection_postgres_replication_role",
        }

    def get_per_db_collection_queries(self) -> set[str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        get_db_major_version(self.db_version)
        return {
            "collection_postgres_extensions",
            "collection_postgres_pglogical_provider_node",
            "collection_postgres_pglogical_privileges",
            "collection_postgres_pglogical_schema_usage_privilege",
            "collection_postgres_user_schemas_without_privilege",
            "collection_postgres_user_tables_without_privilege",
            "collection_postgres_user_views_without_privilege",
            "collection_postgres_user_sequences_without_privilege",
            "collection_postgres_tables_with_no_primary_key",
            "collection_postgres_tables_with_primary_key_replica_identity",
        }

    def get_collection_filenames(self) -> dict[str, str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
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
