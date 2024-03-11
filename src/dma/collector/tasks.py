from sys import version_info
from typing import Literal

from sqlalchemy.ext.asyncio import AsyncSession

from dma.cli._utils import console
from dma.collector.queries import provides_collection_queries
from dma.lib.db.base import get_engine

if version_info < (3, 10):  # pragma: nocover
    from dma.utils import anext_ as anext  # noqa: A001


async def readiness_check(
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
) -> None:
    """Assess the migration readiness for a Database for Database Migration Services"""
    async_engine = get_engine(db_type, username, password, hostname, port, database)
    async with AsyncSession(async_engine) as db_session:
        collection_manager = await anext(provides_collection_queries(db_session))
        _collection = await collection_manager.execute_collection_queries()
        _extended_collection = await collection_manager.execute_extended_collection_queries()
        console.print(_collection)
        console.print(_extended_collection)
