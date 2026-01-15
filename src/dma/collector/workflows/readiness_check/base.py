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

from dma.collector.dependencies import provide_canonical_queries
from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from pathlib import Path

    from rich.console import Console
    from sqlspec.adapters.duckdb import DuckDBDriver

    from dma.lib.db.config import SourceInfo
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


class ReadinessCheck:
    def __init__(
        self,
        driver: "DuckDBDriver",
        src_info: "SourceInfo",
        database: str,
        console: Console,
        collection_identifier: str | None,
        working_path: "Path | None" = None,
    ) -> None:
        self.executor: ReadinessCheckExecutor | None = None
        self.collection_extractor: CollectionExtractor | None = None
        self.driver = driver
        self.src_info = src_info
        self.database = database
        self.console = console
        self.collection_identifier = collection_identifier
        self.working_path = working_path

    def execute(self) -> None:
        self.execute_data_collection()
        self.execute_readiness_check()

    def execute_data_collection(self) -> None:
        canonical_query_manager = next(provide_canonical_queries(driver=self.driver, working_path=self.working_path))

        self.collection_extractor = CollectionExtractor(
            driver=self.driver,
            src_info=self.src_info,
            database=self.database,
            canonical_query_manager=canonical_query_manager,
            console=self.console,
            collection_identifier=self.collection_identifier,
        )
        self.collection_extractor.execute()
        self.db_version = self.collection_extractor.get_db_version()

    def execute_readiness_check(self) -> None:
        """Execute postgres assessments"""
        if self.src_info.db_type == "POSTGRES":
            # lazy loaded to help with circular import issues
            from dma.collector.workflows.readiness_check._postgres.main import (  # noqa: PLC0415
                PostgresReadinessCheckExecutor,
            )

            self.executor = PostgresReadinessCheckExecutor(
                readiness_check=self,
                console=self.console,
            )
            self.executor.execute()
        elif self.src_info.db_type == "MYSQL":
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
            msg = f"{self.src_info.db_type} is not implemented."
            raise ApplicationError(msg)

    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        table = Table(show_header=False)
        table.add_column("title", style="cyan", width=80)
        table.add_row("Migration Readiness Report")
        self.console.print(table)
        if self.executor:
            self.executor.print_summary()
        else:
            msg = f"{self.src_info.db_type} is not implemented."
            raise ApplicationError(msg)


class ReadinessCheckExecutor:
    def __init__(self, console: Console, readiness_check: ReadinessCheck) -> None:
        self.console = console
        self.readiness_check = readiness_check
        self.driver = readiness_check.driver
        self.db_version = readiness_check.db_version

    def execute(self) -> None:
        """Execute checks"""
        msg = "Implement this execution method."
        raise NotImplementedError(msg)

    def get_all_dbs(self) -> set[str]:
        result = self.driver.select("select database_name from extended_collection_postgres_all_databases")
        return {row["database_name"] for row in result}

    def print_summary(self) -> None:
        """Summarizes results"""
        msg = "Implement this execution method."
        raise NotImplementedError(msg)

    def save_rule_result(
        self,
        migration_target: "PostgresVariants | MySQLVariants | OracleVariants | MSSQLVariants",
        rule_code: str,
        severity: "SeverityLevels",
        info: str,
    ) -> None:
        self.driver.execute(
            "insert into readiness_check_summary(migration_target, rule_code, severity, info) values ($migration_target, $rule_code, $severity, $info)",
            migration_target=migration_target,
            rule_code=rule_code,
            severity=severity,
            info=info,
        )
