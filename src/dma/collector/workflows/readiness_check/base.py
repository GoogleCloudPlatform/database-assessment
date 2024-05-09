from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from rich.table import Table

from dma.collector.workflows.collection_extractor._mysql import print_summary_mysql
from dma.collector.workflows.collection_extractor._postgres import print_summary_postgres
from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.collector.workflows.readiness_check._postgres.main import execute_postgres_readiness_check
from dma.lib.exceptions import ApplicationError


@dataclass
class ReadinessCheckTargetConfig:
    db_type: Literal["postgres", "mysql", "oracle"]
    minimum_supported_major_version: float
    maximum_supported_major_version: float | None


class ReadinessCheck(CollectionExtractor):
    async def execute(self) -> None:
        await super().execute()
        await self.extract_collection()
        await self.process_collection()
        self.execute_readiness_check()
        self.print_summary()

    def execute_readiness_check(self) -> None:
        """Execute postgres assessments"""
        if self.db_type == "postgres":
            execute_postgres_readiness_check(
                console=self.console,
                local_db=self.local_db,
                manager=self.canonical_query_manager,
                db_version=self.collection_query_manager.db_version,
            )
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

    def save_rule_result(
        self,
        migration_target: Literal["cloudsql", "alloydb", "bms", "spanner", "bigquery"],
        rule_code: str,
        severity: Literal["error", "warning", "info", "pass"],
        message: str,
    ) -> None:
        self.local_db.execute(
            "insert into readiness_check_summary(migration_target, rule_code, severity, message) values (?,?,?,?)",
            [migration_target, rule_code, severity, message],
        )

    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        table = Table(show_header=False)
        table.add_column("title", style="cyan", width=80)
        table.add_row("Migration Readiness Report")
        self.console.print(table)
        if self.db_type == "postgres":
            print_summary_postgres(console=self.console, local_db=self.local_db, manager=self.canonical_query_manager)
        elif self.db_type == "mysql":
            print_summary_mysql(console=self.console, local_db=self.local_db, manager=self.canonical_query_manager)
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)
