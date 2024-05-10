from __future__ import annotations

from typing import TYPE_CHECKING

from rich.table import Table

from dma.collector.workflows.base import BaseWorkflow
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager, CollectionQueryManager
    from dma.types import SupportedSources


class CollectionExtractor(BaseWorkflow):
    def __init__(
        self,
        local_db: DuckDBPyConnection,
        canonical_query_manager: CanonicalQueryManager,
        collection_query_manager: CollectionQueryManager,
        db_type: SupportedSources,
        console: Console,
    ) -> None:
        self.collection_query_manager = collection_query_manager
        super().__init__(local_db, canonical_query_manager, db_type, console)

    async def execute(self) -> None:
        await super().execute()
        await self.extract_collection()
        await self.process_collection()

    async def extract_collection(self) -> None:
        collection = await self.collection_query_manager.execute_collection_queries()
        self.import_to_table(collection)

    async def process_collection(self) -> None:
        """Process Collections"""

    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        table = Table(show_header=False)
        table.add_column("title", style="cyan", width=80)
        table.add_row("Collection Summary")
        self.console.print(table)
        if self.db_type == "POSTGRES":
            from dma.collector.workflows.collection_extractor._postgres import print_summary_postgres  # noqa: PLC0415

            print_summary_postgres(console=self.console, local_db=self.local_db, manager=self.canonical_query_manager)
        elif self.db_type == "MYSQL":
            from dma.collector.workflows.collection_extractor._mysql import print_summary_mysql  # noqa: PLC0415

            print_summary_mysql(console=self.console, local_db=self.local_db, manager=self.canonical_query_manager)
        else:
            msg = f"{self.db_type} is not implemented."
            raise ApplicationError(msg)
