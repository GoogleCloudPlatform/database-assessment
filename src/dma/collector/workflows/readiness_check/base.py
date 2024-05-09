from __future__ import annotations

from dataclasses import dataclass
from typing import TYPE_CHECKING, Literal

from rich.console import Console
from rich.table import Table

from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.collector.workflows.readiness_check._postgres.main import PostgresReadinessCheckExecutor
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager, CollectionQueryManager


@dataclass
class ReadinessCheckTargetConfig:
    db_type: Literal["postgres", "mysql", "oracle"]
    minimum_supported_major_version: float
    maximum_supported_major_version: float | None


class ReadinessCheck(CollectionExtractor):
    def __init__(
        self,
        local_db: DuckDBPyConnection,
        canonical_query_manager: CanonicalQueryManager,
        collection_query_manager: CollectionQueryManager,
        db_type: Literal["mysql", "postgres", "mssql", "oracle"],
        console: Console,
    ) -> None:
        self.executor: ReadinessCheckExecutor | None = None
        super().__init__(local_db, canonical_query_manager, collection_query_manager, db_type, console)

    async def execute(self) -> None:
        await super().execute()
        await self.extract_collection()
        await self.process_collection()
        self.execute_readiness_check()
        self.print_summary()

    def execute_readiness_check(self) -> None:
        """Execute postgres assessments"""
        if self.db_type == "postgres":
            self.executor = PostgresReadinessCheckExecutor(
                readiness_check=self,
                console=self.console,
            )
            self.executor.execute()
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)

    async def extract_collection(self) -> None:
        await super().extract_collection()
        extended_collection = await self.collection_query_manager.execute_collection_queries()
        self.import_to_table(extended_collection)

    async def process_collection(self) -> None:
        await super().process_collection()
        await self.canonical_query_manager.execute_assessment_queries()

    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        table = Table(show_header=False)
        table.add_column("title", style="cyan", width=80)
        table.add_row("Migration Readiness Report")
        self.console.print(table)
        if self.executor:
            self.print_summary()
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)


class ReadinessCheckExecutor:
    def __init__(self, console: Console, readiness_check: ReadinessCheck) -> None:
        self.console = console
        self.readiness_check = readiness_check
        self.local_db = readiness_check.local_db
        self.canonical_query_manager = readiness_check.canonical_query_manager
        self.db_version = readiness_check.db_type

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
        migration_target: Literal["cloudsql", "alloydb"],
        rule_code: str,
        severity: Literal["error", "warning", "info", "pass"],
        message: str,
    ) -> None:
        self.local_db.execute(
            "insert into readiness_check_summary(migration_target, rule_code, severity, message) values (?,?,?,?)",
            [migration_target, rule_code, severity, message],
        )
