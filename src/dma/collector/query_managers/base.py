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

from typing import TYPE_CHECKING, Any, cast

import aiosql
import psycopg
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

    def execute_ddl_scripts(self, *args: Any, **kwargs: Any) -> None:
        """Execute pre-processing queries."""
        console.print(Padding("CANONICAL DATA MODEL", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Creating tables...[/]") as status:
            for script in self.available_queries("ddl"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                self.execute(script)
                status.console.print(rf" [green]:heavy_check_mark:[/] Created [bold magenta]`{script}`[/]")
            if not self.available_queries("ddl"):
                console.print(" [dim grey]:heavy_check_mark: No DDL scripts to load[/]")


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

    def get_per_db_collection_queries(self) -> set[str]:
        """Get the collection queries that need to be executed for each DB in the instance"""
        msg = "Implement this execution method."
        raise NotImplementedError(msg)

    def get_db_version(self) -> str:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        return self.db_version

    def set_identifiers(
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
        if self.execution_id is None or self.source_id is None or self.db_version is None:
            init_results = self.execute_init_queries()
            self.source_id = (
                source_id if source_id is not None else cast("str | None", init_results.get("init_get_source_id", None))
            )
            self.execution_id = (
                execution_id
                if execution_id is not None
                else cast("str | None", init_results.get("init_get_execution_id", None))
            )
            self.db_version = (
                db_version
                if db_version is not None
                else cast("str | None", init_results.get("init_get_db_version", None))
            )
        if self.source_id is None or self.execution_id is None or self.db_version is None:
            msg = "Failed to set execution identifiers for collection."
            raise ApplicationError(msg)
        if self.expected_collection_queries is None:
            self.expected_collection_queries = self.get_collection_queries()

    def execute_init_queries(
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
                script_result = self.select_one_value(script)
                results[script] = script_result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.available_queries("init"):
                status.console.print(
                    " [dim grey]:heavy_check_mark: No initialization queries for this database type[/]"
                )
            return results

    def execute_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        *args: Any,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Execute pre-processing queries."""
        self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("COLLECTION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in self.get_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                script_result = self.select(
                    script, PKEY=self.execution_id, DMA_SOURCE_ID=self.source_id, DMA_MANUAL_ID=self.manual_id
                )
                results[script] = script_result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.get_collection_queries():
                status.console.print(" [dim grey]:heavy_check_mark: No collection queries for this database type[/]")
            return results

    def execute_extended_collection_queries(
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
        self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("EXTENDED COLLECTION QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in self.get_extended_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                script_result = self.select(
                    script, PKEY=self.execution_id, DMA_SOURCE_ID=self.source_id, DMA_MANUAL_ID=self.manual_id
                )
                results[script] = script_result
                status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
            if not self.get_extended_collection_queries():
                console.print(" [dim grey]:heavy_check_mark: No extended collection queries for this database type[/]")
            return results

    def execute_per_db_collection_queries(
        self,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        *args: Any,
        **kwargs: Any,
    ) -> dict[str, Any]:
        """Execute per DB pre-processing queries."""
        self.set_identifiers(execution_id=execution_id, source_id=source_id, manual_id=manual_id)
        console.print(Padding("PER DB QUERIES", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Executing queries...[/]") as status:
            results: dict[str, Any] = {}
            for script in self.get_per_db_collection_queries():
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                try:
                    script_result = self.select(
                        script, PKEY=self.execution_id, DMA_SOURCE_ID=self.source_id, DMA_MANUAL_ID=self.manual_id
                    )
                    results[script] = script_result
                    status.console.print(rf" [green]:heavy_check_mark:[/] Gathered [bold magenta]`{script}`[/]")
                except psycopg.errors.UndefinedTable:
                    status.console.print(rf"Skipped `{script}` as the table doesn't exist")
                except psycopg.errors.InsufficientPrivilege:
                    status.console.print(rf"Skipped `{script}` due to insufficient privileges.")
            if not self.get_per_db_collection_queries():
                status.console.print(
                    " [dim grey]:heavy_check_mark: No DB specific collection queries for this database type[/]"
                )
            return results
