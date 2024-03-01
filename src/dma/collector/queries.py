"""User Account Controllers."""

from __future__ import annotations

from typing import TYPE_CHECKING, AsyncIterator

import aiosql

from dma import utils
from dma.collector.query_manager import CollectionQueryManager
from dma.exceptions import ApplicationError

if TYPE_CHECKING:
    from sqlalchemy.ext.asyncio import AsyncSession


async def provides_collection_queries(
    db_session: AsyncSession,
) -> AsyncIterator[CollectionQueryManager]:
    """Construct repository and service objects for the request."""
    dialect = db_session.bind.dialect if db_session.bind is not None else db_session.get_bind().dialect
    db_connection = await db_session.connection()

    raw_connection = await db_connection.get_raw_connection()
    if not raw_connection.driver_connection:
        msg = "Unable to fetch raw connection from session."
        raise ApplicationError(msg)
    rdbms_type = dialect.name
    if rdbms_type == "postgresql":
        driver_adapter = "asyncpg"
    elif rdbms_type == "mysql":
        driver_adapter = "mysql"
    elif rdbms_type == "oracle":
        driver_adapter = "oracle"
    elif rdbms_type == "mysql":
        driver_adapter = "mysql"
    else:
        msg = "Unable to identify driver adapter from dialect."
        raise ApplicationError(msg)
    sql_path = f"{utils.module_to_os_path('dma')}/collector/sql/{rdbms_type}"
    queries = aiosql.from_path(sql_path=sql_path, driver_adapter=driver_adapter)
    async with CollectionQueryManager.from_connection(
        queries,
        connection=raw_connection.driver_connection,
    ) as query_manager:
        yield query_manager
