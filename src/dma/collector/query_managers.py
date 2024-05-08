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

from typing import TYPE_CHECKING, Any

import aiosql
from rich.padding import Padding

from dma.cli._utils import console
from dma.lib.db.query_manager import QueryManager
from dma.lib.exceptions import ApplicationError
from dma.utils import module_to_os_path

if TYPE_CHECKING:
    from aiosql.queries import Queries

_root_path = module_to_os_path("dma")


class CanonicalQueryManager(QueryManager):
    """Canonical Query Manager"""

    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(sql_path=f"{_root_path}/collector/sql/canonical/", driver_adapter="duckdb"),
    ) -> None:
        self.execution_id = execution_id
        self.source_id = source_id
        self.manual_id = manual_id
        super().__init__(connection, queries)

    async def execute_ddl_scripts(self, *args: Any, **kwargs: Any) -> None:
        """Execute pre-processing queries."""
        console.print(Padding("DATAMODEL", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Creating tables...[/]") as status:
            for script in self.available_queries("ddl"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                await self.execute(script)
                status.console.print(rf" [green]:heavy_check_mark:[/] Created [bold magenta]`{script}`[/]")
            if not self.available_queries("ddl"):
                console.print(" [dim grey]:heavy_check_mark: No DDL scripts to load[/]")

    async def execute_transformation_queries(self, *args: Any, **kwargs: Any) -> None:
        """Execute pre-processing queries."""
        console.print(Padding("TRANSFORMATION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            for script in self.available_queries("transformation"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                await self.execute(script)
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.available_queries("transformation"):
                console.print(" [dim grey]:heavy_check_mark: No transformation queries for this database type[/]")

    async def execute_assessment_queries(
        self,
        *args: Any,
        **kwargs: Any,
    ) -> None:
        """Execute pre-processing queries."""
        console.print(Padding("ASSESSMENT QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            for script in self.available_queries("assessment"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                await self.insert_update_delete(script)
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.available_queries("assessment"):
                console.print(" [dim grey]:heavy_check_mark: No assessment queries for this database type[/]")


class CollectionQueryManager(QueryManager):
    """Collection Query Manager"""

    def __init__(
        self,
        connection: Any,
        queries: Queries,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        db_version: str | None = None,
        expected_queries: set[str] | None = None,
    ) -> None:
        self.execution_id = execution_id
        self.source_id = source_id
        self.manual_id = manual_id
        self.db_version = db_version
        self.expected_collection_queries = expected_queries
        super().__init__(connection, queries)

    def get_collection_queries(self) -> set[str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        return set(self.available_queries("collection"))

    def get_extended_collection_queries(self) -> set[str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        return set(self.available_queries("extended_collection"))

    async def set_identifiers(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        db_version: str | None = None,
    ) -> None:
        """Execute pre-processing queries."""
        if execution_id is not None:
            self.execution_id = execution_id
        if source_id is not None:
            self.source_id = source_id
        if manual_id is not None:
            self.manual_id = manual_id
        if db_version is not None:
            self.db_version = db_version
        if execution_id is None or source_id is None or db_version is None:
            init_results = await self.execute_init_queries()
            self.source_id = source_id if source_id is not None else init_results.get("init_get_source_id", None)
            self.execution_id = (
                execution_id if execution_id is not None else init_results.get("init_get_execution_id", None)
            )
            self.db_version = db_version if db_version is not None else init_results.get("init_get_db_version", None)
        if self.source_id is None or self.execution_id is None or self.db_version is None:
            msg = "Failed to set execution identifiers for collection."
            raise ApplicationError(msg)
        if self.expected_collection_queries is None:
            self.expected_collection_queries = self.get_collection_queries()

    async def execute_init_queries(
        self,
        *args: Any,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Execute pre-processing queries."""
        console.print(Padding("SCRIPT INITIALIZATION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in self.available_queries("init"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                script_result = await self.select_one_value(script)
                results[script] = script_result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.available_queries("init"):
                status.console.print(
                    " [dim grey]:heavy_check_mark: No initialization queries for this database type[/]"
                )
            return results

    async def execute_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        *args: Any,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Execute pre-processing queries."""
        await self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("COLLECTION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in self.get_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                script_result = await self.select(
                    script, PKEY=self.execution_id, DMA_SOURCE_ID=self.source_id, DMA_MANUAL_ID=self.manual_id
                )
                results[script] = script_result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.get_collection_queries():
                status.console.print(" [dim grey]:heavy_check_mark: No collection queries for this database type[/]")
            return results

    async def execute_extended_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        *args: Any,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Execute extended collection queries.

        Returns: None
        """
        await self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("EXTENDED COLLECTION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in self.get_extended_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                script_result = await self.select(
                    script, PKEY=self.execution_id, DMA_SOURCE_ID=self.source_id, DMA_MANUAL_ID=self.manual_id
                )
                results[script] = script_result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.get_extended_collection_queries():
                console.print(" [dim grey]:heavy_check_mark: No extended collection queries for this database type[/]")
            return results


class PostgresCollectionQueryManager(CollectionQueryManager):
    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(
            sql_path=f"{_root_path}/collector/sql/sources/postgres", driver_adapter="asyncpg"
        ),
    ) -> None:
        super().__init__(
            connection=connection, queries=queries, execution_id=execution_id, source_id=source_id, manual_id=manual_id
        )

    def get_collection_queries(self) -> set[str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        major_version = int(self.db_version[:2])
        version_prefix = "base" if major_version > 13 else "13" if major_version == 13 else "12"
        return {
            f"collection_postgres_{version_prefix}_table_details",
            f"collection_postgres_{version_prefix}_database_details",
            f"collection_postgres_{version_prefix}_replication_slots",
            "collection_postgres_applications",
            "collection_postgres_aws_extension_dependency",
            "collection_postgres_aws_oracle_exists",
            "collection_postgres_bg_writer_stats",
            "collection_postgres_calculated_metrics",
            "collection_postgres_data_types",
            "collection_postgres_extensions",
            "collection_postgres_index_details",
            "collection_postgres_replication_stats",
            "collection_postgres_schema_details",
            "collection_postgres_schema_objects",
            "collection_postgres_settings",
            "collection_postgres_source_details",
        }

    def get_collection_filenames(self) -> dict[str, str]:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        major_version = int(self.db_version[:2])
        version_prefix = "base" if major_version > 13 else "13" if major_version == 13 else "12"
        return {
            f"collection_postgres_{version_prefix}_table_details": "collection_postgres_table_details",
            f"collection_postgres_{version_prefix}_database_details": "collection_postgres_database_details",
            f"collection_postgres_{version_prefix}_replication_slots": "collection_postgres_replication_slots",
            "collection_postgres_applications": "collection_postgres_applications",
            "collection_postgres_aws_extension_dependency": "collection_postgres_aws_extension_dependency",
            "collection_postgres_aws_oracle_exists": "collection_postgres_aws_oracle_exists",
            "collection_postgres_bg_writer_stats": "collection_postgres_bg_writer_stats",
            "collection_postgres_calculated_metrics": "collection_postgres_calculated_metrics",
            "collection_postgres_data_types": "collection_postgres_data_types",
            "collection_postgres_extensions": "collection_postgres_extensions",
            "collection_postgres_index_details": "collection_postgres_index_details",
            "collection_postgres_replication_stats": "collection_postgres_replication_stats",
            "collection_postgres_schema_details": "collection_postgres_schema_details",
            "collection_postgres_schema_objects": "collection_postgres_schema_objects",
            "collection_postgres_settings": "collection_postgres_settings",
            "collection_postgres_source_details": "collection_postgres_source_details",
        }


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
        major_version = int(self.db_version[:2])
        version_prefix = "base" if major_version > 5.8 else "5.6"
        return {
            f"collection_mysql_{version_prefix}_resource_groups",
            "collection_mysql_config",
            "collection_mysql_data_types",
            "collection_mysql_database_details",
            "collection_mysql_engines",
            "collection_mysql_plugins",
            "collection_mysql_process_list",
            "collection_mysql_schema_objects",
            "collection_mysql_table_details",
            "collection_mysql_users",
        }


class OracleCollectionQueryManager(CollectionQueryManager):
    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(
            sql_path=f"{_root_path}/collector/sql/sources/oracle", driver_adapter="async_oracledb"
        ),
    ) -> None:
        super().__init__(
            connection=connection, queries=queries, execution_id=execution_id, source_id=source_id, manual_id=manual_id
        )


class SQLServerCollectionQueryManager(CollectionQueryManager):
    def __init__(
        self,
        connection: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        queries: Queries = aiosql.from_path(
            sql_path=f"{_root_path}/collector/sql/sources/mssql", driver_adapter="aioodbc"
        ),
    ) -> None:
        super().__init__(
            connection=connection, queries=queries, execution_id=execution_id, source_id=source_id, manual_id=manual_id
        )