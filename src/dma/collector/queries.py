"""User Account Controllers."""

from __future__ import annotations

from typing import TYPE_CHECKING

import aiosql

from dma.collector.query_manager import CanonicalQueryManager, CollectionQueryManager
from dma.lib.db.local import get_duckdb_connection
from dma.lib.exceptions import ApplicationError
from dma.utils import module_to_os_path

if TYPE_CHECKING:
    from collections.abc import AsyncIterator, Generator
    from pathlib import Path

    import duckdb
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


def provide_canonical_queries(
    local_db: duckdb.DuckDBPyConnection | None = None, working_path: Path | None = None
) -> Generator[CanonicalQueryManager, None, None]:
    """Construct repository and service objects for the request."""
    if local_db:
        yield CanonicalQueryManager(connection=local_db, queries=canonical_queries)
    else:
        with get_duckdb_connection(working_path=working_path) as db_connection:
            yield CanonicalQueryManager(connection=db_connection, queries=canonical_queries)
