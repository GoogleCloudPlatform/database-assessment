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

from dma.collector.query_managers import CanonicalQueryManager
from dma.lib.db.local import get_duckdb_connection
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from collections.abc import Generator, Iterator
    from pathlib import Path

    import duckdb
    from sqlalchemy.orm import Session

    from dma.collector.query_managers import CollectionQueryManager


def provide_collection_query_manager(
    db_session: Session,
    execution_id: str | None = None,
    source_id: str | None = None,
    manual_id: str | None = None,
) -> Iterator[CollectionQueryManager]:
    """Provide collection query manager.

    Uses SQLAlchemy Connection management to establish and retrieve a valid database session.

    The driver dialect is detected from the session and the underlying raw DBAPI connection is fetched and passed to the Query Manager.
    """
    dialect = db_session.bind.dialect if db_session.bind is not None else db_session.get_bind().dialect
    db_connection = db_session.connection()

    raw_connection = db_connection.engine.raw_connection()
    if not raw_connection.driver_connection:
        msg = "Unable to fetch raw connection from session."
        raise ApplicationError(msg)
    rdbms_type = dialect.name
    if rdbms_type == "postgresql":
        from psycopg.rows import dict_row  # noqa: PLC0415

        from dma.collector.query_managers import PostgresCollectionQueryManager  # noqa: PLC0415

        raw_connection.driver_connection.row_factory = dict_row
        query_manager: CollectionQueryManager = PostgresCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    elif rdbms_type == "mysql":
        from dma.collector.query_managers import MySQLCollectionQueryManager  # noqa: PLC0415

        query_manager = MySQLCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    elif rdbms_type == "oracle":
        from dma.collector.query_managers import OracleCollectionQueryManager  # noqa: PLC0415

        query_manager = OracleCollectionQueryManager(
            connection=raw_connection.driver_connection,
            manual_id=manual_id,
            source_id=source_id,
            execution_id=execution_id,
        )
    elif rdbms_type == "mssql":
        from dma.collector.query_managers import SQLServerCollectionQueryManager  # noqa: PLC0415

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
    local_db: duckdb.DuckDBPyConnection | None = None,
    working_path: Path | None = None,
    export_path: Path | None = None,
) -> Generator[CanonicalQueryManager, None, None]:
    """Construct repository and service objects for the request."""
    if local_db:
        yield CanonicalQueryManager(connection=local_db)
    else:
        with get_duckdb_connection(working_path=working_path, export_path=export_path) as db_connection:
            yield CanonicalQueryManager(connection=db_connection)
