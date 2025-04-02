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
from dma.lib.exceptions import ApplicationError
from dma.utils import module_to_os_path

if TYPE_CHECKING:
    from aiosql.queries import Queries

_root_path = module_to_os_path("dma")


class MySQLCollectionQueryManager(CollectionQueryManager):
    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(
            sql_path=f"{_root_path}/collector/sql/sources/mysql", driver_adapter="asyncmy"
        ),
    ) -> None:
        super().__init__(
            connection=connection, queries=queries, execution_id=execution_id, source_id=source_id, manual_id=manual_id
        )

    def get_collection_queries(self) -> set[str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        major_version = int(self.db_version[:1])
        version_prefix = "base" if major_version > 5.8 else "5"
        return {
            f"collection_mysql_{version_prefix}_resource_groups",
            f"collection_mysql_{version_prefix}_process_list",
            "collection_mysql_config",
            "collection_mysql_data_types",
            "collection_mysql_database_details",
            "collection_mysql_engines",
            "collection_mysql_plugins",
            "collection_mysql_schema_objects",
            "collection_mysql_table_details",
            "collection_mysql_users",
        }

    def get_collection_filenames(self) -> dict[str, str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        major_version = int(self.db_version[:1])
        version_prefix = "base" if major_version > 5.8 else "5"
        return {
            f"collection_mysql_{version_prefix}_resource_groups": "mysql_resource_groups",
            f"collection_mysql_{version_prefix}_process_list": "mysql_process_list",
            "collection_mysql_config": "mysql_config",
            "collection_mysql_data_types": "mysql_data_types",
            "collection_mysql_database_details": "mysql_database_details",
            "collection_mysql_engines": "mysql_engines",
            "collection_mysql_plugins": "mysql_plugins",
            "collection_mysql_schema_objects": "mysql_schema_objects",
            "collection_mysql_table_details": "mysql_table_details",
            "collection_mysql_users": "mysql_users",
        }
