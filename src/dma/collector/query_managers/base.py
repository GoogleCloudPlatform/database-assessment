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
"""Query managers for database data collection using SQLSpec.

This module provides base classes for query managers that handle SQL query
execution against source databases and the canonical DuckDB database.

The query managers use SQLSpec for database connectivity and query execution,
supporting both dict-based results and Arrow-native data transfer.
"""

from __future__ import annotations

from typing import TYPE_CHECKING, Any

from rich.padding import Padding

from dma.cli._utils import console
from dma.lib.db.manager import get_available_queries, get_sql
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from sqlspec.adapters.duckdb import DuckDBDriver


class CanonicalQueryManager:
    """Canonical Query Manager for DuckDB operations.

    Handles DDL execution and query execution against the local DuckDB
    database used for canonical data model and analysis.
    """

    def __init__(
        self,
        driver: "DuckDBDriver",
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
    ) -> None:
        """Initialize the canonical query manager.

        Args:
            driver: SQLSpec DuckDB driver instance.
            execution_id: Unique execution identifier.
            source_id: Source database identifier.
            manual_id: Manual collection identifier.
        """
        self.driver = driver
        self.execution_id = execution_id
        self.source_id = source_id
        self.manual_id = manual_id

    @staticmethod
    def available_queries(prefix: str | None = None) -> list[str]:
        """Get available queries optionally filtered by prefix.

        Args:
            prefix: If provided, only return queries starting with this prefix.

        Returns:
            Sorted list of query names.
        """
        return get_available_queries(prefix)

    def execute(self, query_name: str, **binds: Any) -> None:
        """Execute a query (typically DDL).

        Args:
            query_name: Name of the query to execute.
            **binds: Parameter bindings for the query.
        """
        self.driver.execute(get_sql(query_name).sql, **binds)

    def select(self, query_name: str, **binds: Any) -> list[dict[str, Any]]:
        """Execute a SELECT query and return results as dicts.

        Args:
            query_name: Name of the query to execute.
            **binds: Parameter bindings for the query.

        Returns:
            List of result rows as dictionaries.
        """
        return self.driver.select(get_sql(query_name).sql, **binds)

    def select_one_value(self, query_name: str, **binds: Any) -> Any:
        """Execute a query and return a single scalar value.

        Args:
            query_name: Name of the query to execute.
            **binds: Parameter bindings for the query.

        Returns:
            The scalar value from the query result.
        """
        return self.driver.select_value(get_sql(query_name).sql, **binds)

    def execute_ddl_scripts(self) -> None:
        """Execute DDL scripts to create canonical tables."""
        console.print(Padding("CANONICAL DATA MODEL", 1, style="bold", expand=True), width=80)
        with console.status("[bold green]Creating tables...[/]") as status:
            for script in self.available_queries("ddl"):
                status.update(rf" [yellow]*[/] Executing [bold magenta]`{script}`[/]")
                self.execute(script)
                status.console.print(rf" [green]:heavy_check_mark:[/] Created [bold magenta]`{script}`[/]")
            if not self.available_queries("ddl"):
                console.print(" [dim grey]:heavy_check_mark: No DDL scripts to load[/]")


class CollectionQueryManager:
    """Base collection query manager.

    Provides the foundation for database-specific collection query managers.
    Subclasses implement get_collection_queries() to provide version-specific
    query selection.
    """

    def __init__(
        self,
        driver: Any,
        execution_id: str | None = None,
        source_id: str | None = None,
        manual_id: str | None = None,
        db_version: str | None = None,
        expected_queries: set[str] | None = None,
    ) -> None:
        """Initialize the collection query manager.

        Args:
            driver: SQLSpec driver instance.
            execution_id: Unique execution identifier.
            source_id: Source database identifier.
            manual_id: Manual collection identifier.
            db_version: Database version string.
            expected_queries: Expected collection queries (for validation).
        """
        self.driver = driver
        self.execution_id = execution_id
        self.source_id = source_id
        self.manual_id = manual_id
        self.db_version = db_version
        self.expected_collection_queries = expected_queries

    @staticmethod
    def available_queries(prefix: str | None = None) -> list[str]:
        """Get available queries optionally filtered by prefix.

        Args:
            prefix: If provided, only return queries starting with this prefix.

        Returns:
            Sorted list of query names.
        """
        return get_available_queries(prefix)

    def get_collection_queries(self) -> set[str]:
        """Get the set of collection query names.

        Must be overridden by subclasses.

        Returns:
            Set of query names for collection.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        return set(self.available_queries("collection"))

    def get_extended_collection_queries(self) -> set[str]:
        """Get the set of extended collection query names.

        Returns:
            Set of extended collection query names.
        """
        if self.db_version is None:
            msg = "Database Version was not set. Ensure the initialization step completed successfully."
            raise ApplicationError(msg)
        return set(self.available_queries("extended-collection"))

    def get_per_db_collection_queries(self) -> set[str]:
        """Get collection queries for per-database execution.

        Must be overridden by subclasses.

        Raises:
            NotImplementedError: Always raised, subclasses must implement.
        """
        msg = "Implement this execution method."
        raise NotImplementedError(msg)

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

    def select(self, query_name: str, **binds: Any) -> list[dict[str, Any]]:
        """Execute a SELECT query and return results as dicts.

        Args:
            query_name: Name of the query to execute.
            **binds: Parameter bindings for the query.

        Returns:
            List of result rows as dictionaries.
        """
        return self.driver.select(get_sql(query_name).sql, **binds)

    def select_one_value(self, query_name: str, **binds: Any) -> Any:
        """Execute a query and return a single scalar value.

        Args:
            query_name: Name of the query to execute.
            **binds: Parameter bindings for the query.

        Returns:
            The scalar value from the query result.
        """
        return self.driver.select_value(get_sql(query_name).sql, **binds)
