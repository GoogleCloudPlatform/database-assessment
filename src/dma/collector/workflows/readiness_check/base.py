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

from dataclasses import dataclass
from typing import TYPE_CHECKING

from rich.console import Console
from rich.table import Table

from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager, CollectionQueryManager
    from dma.types import (
        MSSQLVariants,
        MySQLVariants,
        OracleVariants,
        PostgresVariants,
        SeverityLevels,
        SupportedSources,
    )


@dataclass
class ReadinessCheckTargetConfig:
    db_type: SupportedSources
    minimum_supported_major_version: float
    maximum_supported_major_version: float | None


class ReadinessCheck(CollectionExtractor):
    def __init__(
        self,
        local_db: DuckDBPyConnection,
        canonical_query_manager: CanonicalQueryManager,
        collection_query_manager: CollectionQueryManager,
        db_type: SupportedSources,
        console: Console,
    ) -> None:
        self.executor: ReadinessCheckExecutor | None = None
        super().__init__(local_db, canonical_query_manager, collection_query_manager, db_type, console)

    async def execute(self) -> None:
        await super().execute()
        self.execute_readiness_check()

    def execute_readiness_check(self) -> None:
        """Execute postgres assessments"""
        if self.db_type == "POSTGRES":
            # lazy loaded to help with circular import issues
            from dma.collector.workflows.readiness_check._postgres.main import (  # noqa: PLC0415
                PostgresReadinessCheckExecutor,
            )

            self.executor = PostgresReadinessCheckExecutor(
                readiness_check=self,
                console=self.console,
            )
            self.executor.execute()
        elif self.db_type == "MYSQL":
            # lazy loaded to help with circular import issues
            from dma.collector.workflows.readiness_check._mysql.main import (  # noqa: PLC0415
                MySQLReadinessCheckExecutor,
            )

            self.executor = MySQLReadinessCheckExecutor(
                readiness_check=self,
                console=self.console,
            )
            self.executor.execute()
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)

    async def extract_collection(self) -> None:
        await super().extract_collection()
        extended_collection = await self.collection_query_manager.execute_extended_collection_queries()
        self.import_to_table(extended_collection)

    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        table = Table(show_header=False)
        table.add_column("title", style="cyan", width=80)
        table.add_row("Migration Readiness Report")
        self.console.print(table)
        if self.executor:
            self.executor.print_summary()
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)


class ReadinessCheckExecutor:
    def __init__(self, console: Console, readiness_check: ReadinessCheck) -> None:
        self.console = console
        self.readiness_check = readiness_check
        self.local_db = readiness_check.local_db
        self.canonical_query_manager = readiness_check.canonical_query_manager
        self.db_version = readiness_check.collection_query_manager.db_version

    def execute(self) -> None:  # noqa: PLR6301
        """Execute checks"""
        msg = "Implement this execution method."
        raise NotImplementedError(msg)

    def print_summary(self) -> None:  # noqa: PLR6301
        """Summarizes results"""
        msg = "Implement this execution method."
        raise NotImplementedError(msg)

    def save_rule_result(
        self,
        migration_target: PostgresVariants | MySQLVariants | OracleVariants | MSSQLVariants,
        rule_code: str,
        severity: SeverityLevels,
        info: str,
    ) -> None:
        self.local_db.execute(
            "insert into readiness_check_summary(migration_target, rule_code, severity, info) values (?,?,?,?)",
            [migration_target, rule_code, severity, info],
        )
