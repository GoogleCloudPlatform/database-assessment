"""User Account Controllers."""

from __future__ import annotations

from typing import TYPE_CHECKING

import aiosql

from dma.collector.query_manager import CollectionQueryManager
from dma.lib.exceptions import ApplicationError
from dma.utils import module_to_os_path

if TYPE_CHECKING:
    from collections.abc import AsyncIterator

    from sqlalchemy.ext.asyncio import AsyncSession

_root_path = module_to_os_path("dma")

canonical_queries = aiosql.from_path(sql_path=f"{_root_path}/collector/sql/canonical", driver_adapter="duckdb")
postgres_queries = aiosql.from_path(sql_path=f"{_root_path}/collector/sql/sources/postgres", driver_adapter="asyncpg")
mysql_queries = aiosql.from_path(sql_path=f"{_root_path}/collector/sql/sources/mysql", driver_adapter="asyncmy")
oracle_queries = aiosql.from_path(
    sql_path=f"{_root_path}/collector/sql/sources/oracle", driver_adapter="async_oracledb"
)
mssql_queries = aiosql.from_path(sql_path=f"{_root_path}/collector/sql/sources/mssql", driver_adapter="aioodbc")


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
        query_manager = CollectionQueryManager(connection=raw_connection.driver_connection, queries=postgres_queries)
    elif rdbms_type == "mysql":
        query_manager = CollectionQueryManager(connection=raw_connection.driver_connection, queries=mysql_queries)
    elif rdbms_type == "oracle":
        query_manager = CollectionQueryManager(connection=raw_connection.driver_connection, queries=oracle_queries)
    elif rdbms_type == "mssql":
        query_manager = CollectionQueryManager(connection=raw_connection.driver_connection, queries=mssql_queries)
    else:
        msg = "Unable to identify driver adapter from dialect."
        raise ApplicationError(msg)
    yield query_manager
