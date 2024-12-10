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

from datetime import datetime, timezone
from typing import TYPE_CHECKING

from rich.table import Table
from sqlalchemy.ext.asyncio import AsyncSession

from dma.__about__ import __version__ as current_version
from dma.collector.dependencies import provide_collection_query_manager
from dma.collector.workflows.base import BaseWorkflow
from dma.lib.db.base import SourceInfo, get_engine
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager, CollectionQueryManager


class CollectionExtractor(BaseWorkflow):
    def __init__(
        self,
        local_db: DuckDBPyConnection,
        src_info: SourceInfo,
        database: str,
        canonical_query_manager: CanonicalQueryManager,
        console: Console,
        collection_identifier: str | None,
    ) -> None:
        self.src_info = src_info
        self.database = database
        self.collection_identifier = collection_identifier
        super().__init__(local_db, canonical_query_manager, src_info.db_type, console)

    async def execute(self) -> None:
        await super().execute()
        execution_id = (
            f"{self.src_info.db_type}_{current_version!s}_{datetime.now(tz=timezone.utc).strftime('%y%m%d%H%M%S')}"
        )
        await self.collect_data(execution_id)
        await self.collect_db_specific_data(execution_id)

    async def collect_data(self, execution_id: str) -> None:
        async_engine = get_engine(self.src_info, self.database)
        async with AsyncSession(async_engine) as db_session:
            collection_manager = await anext(  # noqa: F821 # pyright: ignore[reportUndefinedVariable]
                provide_collection_query_manager(
                    db_session=db_session, execution_id=execution_id, manual_id=self.collection_identifier
                )
            )
            await self.extract_collection(collection_manager)
            await self.extract_extended_collection(collection_manager)
            await self.process_collection()
            self.db_version = collection_manager.get_db_version()
        await async_engine.dispose()

    async def collect_db_specific_data(self, execution_id: str) -> None:
        dbs = await self.get_all_dbs()
        for db in dbs:
            async_engine = get_engine(src_info=self.src_info, database=db)
            async with AsyncSession(async_engine) as db_session:
                collection_manager = await anext(  # noqa: F821 # pyright: ignore[reportUndefinedVariable]
                    provide_collection_query_manager(
                        db_session=db_session, execution_id=execution_id, manual_id=self.collection_identifier
                    )
                )
                db_collection = await collection_manager.execute_per_db_collection_queries()
                self.import_to_table(db_collection)
            await async_engine.dispose()

    async def get_all_dbs(self) -> set[str]:
        result = self.local_db.sql("""
            select database_name from extended_collection_postgres_all_databases
        """).fetchall()
        return {row[0] for row in result}

    def get_db_version(self) -> str:
        if self.db_version is None:
            msg = "Database Version was not set.  Ensure the initialization step complete successfully."
            raise ApplicationError(msg)
        return self.db_version

    async def extract_collection(self, collection_query_manager: CollectionQueryManager) -> None:
        collection = await collection_query_manager.execute_collection_queries()
        self.import_to_table(collection)

    async def extract_extended_collection(self, collection_query_manager: CollectionQueryManager) -> None:
        extended_collection = await collection_query_manager.execute_extended_collection_queries()
        self.import_to_table(extended_collection)

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
