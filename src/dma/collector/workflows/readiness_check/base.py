from __future__ import annotations

from rich.table import Table

from dma.collector.workflows.collection_extractor._mysql import print_summary_mysql
from dma.collector.workflows.collection_extractor._postgres import print_summary_postgres
from dma.collector.workflows.collection_extractor.base import CollectionExtractor
from dma.lib.exceptions import ApplicationError


class ReadinessCheck(CollectionExtractor):
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
        if self.db_type == "postgres":
            print_summary_postgres(console=self.console, local_db=self.local_db, manager=self.canonical_query_manager)
        elif self.db_type == "mysql":
            print_summary_mysql(console=self.console, local_db=self.local_db, manager=self.canonical_query_manager)
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)
