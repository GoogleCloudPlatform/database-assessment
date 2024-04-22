from __future__ import annotations

from sys import version_info
from typing import TYPE_CHECKING, Literal

from sqlalchemy.ext.asyncio import AsyncSession

from dma.collector.dependencies import provide_canonical_queries, provide_collection_query_manager
from dma.collector.workflows import ReadinessCheck
from dma.lib.db.base import get_engine
from dma.lib.db.local import get_duckdb_connection

if TYPE_CHECKING:
    from pathlib import Path

    from rich.console import Console


if version_info < (3, 10):  # pragma: nocover
    from dma.utils import anext_ as anext  # noqa: A001


async def readiness_check(
    console: Console,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
    # pkey: str,
    # dma_source_id: str,
    # dma_manual_id: str,
    working_path: Path | None = None,
) -> None:
    """Assess the migration readiness for a Database for Database Migration Services"""
    async_engine = get_engine(db_type, username, password, hostname, port, database)
    with get_duckdb_connection(working_path) as local_db:
        async with AsyncSession(async_engine) as db_session:
            collection_manager = await anext(provide_collection_query_manager(db_session))
            pipeline_manager = next(provide_canonical_queries(local_db))
            readiness_check = ReadinessCheck(
                local_db=local_db, canonical_query_manager=pipeline_manager, db_type=db_type, console=console
            )
            # collect data

            collection = await collection_manager.execute_collection_queries()
            extended_collection = await collection_manager.execute_extended_collection_queries()
            # import data locally
            readiness_check.import_to_table(collection)
            readiness_check.import_to_table(extended_collection)

            # transform data
            await readiness_check.process_collection()
            # print summary
            readiness_check.print_summary()
        await async_engine.dispose()
