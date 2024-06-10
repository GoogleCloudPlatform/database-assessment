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

from typing import TYPE_CHECKING

from dma.collector.query_managers import (
    CanonicalQueryManager,
    CollectionQueryManager,
    MySQLCollectionQueryManager,
    OracleCollectionQueryManager,
    PostgresCollectionQueryManager,
    SQLServerCollectionQueryManager,
)
from dma.lib.db.local import get_duckdb_connection
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from collections.abc import AsyncIterator, Generator
    from pathlib import Path

    import duckdb
    from sqlalchemy.ext.asyncio import AsyncSession


async def provide_collection_query_manager(
    db_session: AsyncSession,
    execution_id: str | None = None,
    source_id: str | None = None,
    manual_id: str | None = None,
) -> AsyncIterator[CollectionQueryManager]:
    """Provide collection query manager.

    Uses SQLAlchemy Connection management to establish and retrieve a valid database session.

    The driver dialect is detected from the session and the underlying raw DBAPI connection is fetched and passed to the Query Manager.
    """
    dialect = db_session.bind.dialect if db_session.bind is not None else db_session.get_bind().dialect
    db_connection = await db_session.connection()

    raw_connection = await db_connection.get_raw_connection()
    if not raw_connection.driver_connection:
        msg = "Unable to fetch raw connection from session."
        raise ApplicationError(msg)
    rdbms_type = dialect.name
    if rdbms_type == "postgresql":
        query_manager: CollectionQueryManager = PostgresCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    elif rdbms_type == "mysql":
        query_manager = MySQLCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    elif rdbms_type == "oracle":
        query_manager = OracleCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    elif rdbms_type == "mssql":
        query_manager = SQLServerCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    else:
        msg = "Unable to identify driver adapter from dialect."
        raise ApplicationError(msg)
    yield query_manager


def provide_canonical_queries(
    local_db: duckdb.DuckDBPyConnection | None = None, working_path: Path | None = None
) -> Generator[CanonicalQueryManager, None, None]:
    """Construct repository and service objects for the request."""
    if local_db:
        yield CanonicalQueryManager(connection=local_db)
    else:
        with get_duckdb_connection(working_path=working_path) as db_connection:
            yield CanonicalQueryManager(connection=db_connection)
