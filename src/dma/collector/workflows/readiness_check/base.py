from __future__ import annotations

from typing import TYPE_CHECKING, Literal

from rich.table import Table

from dma.collector.workflows.base import BaseWorkflow
from dma.collector.workflows.readiness_check._mysql import print_summary_mysql
from dma.collector.workflows.readiness_check._postgres import print_summary_postgres

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager


class ReadinessCheck(BaseWorkflow):
    def __init__(
        self,
        local_db: DuckDBPyConnection,
        canonical_query_manager: CanonicalQueryManager,
        db_type: Literal["mysql", "postgres", "mssql", "oracle"],
        console: Console,
    ) -> None:
        super().__init__(local_db, canonical_query_manager, db_type, console)

    async def process_collection(self) -> None:
        await self.canonical_query_manager.execute_transformation_queries()
        await self.canonical_query_manager.execute_assessment_queries()

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
            raise NotImplementedError(msg)
