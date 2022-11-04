# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from contextlib import contextmanager
from typing import TYPE_CHECKING, Any, Dict, Iterator, List, Optional, TypeVar, Union, cast

from aiosql.types import SQLOperationType, SyncDriverAdapterProtocol

if TYPE_CHECKING:
    from datetime import datetime

    from duckdb import DuckDBPyConnection

RecordClassType = TypeVar("RecordClassType", bound=Any)  # pylint: disable=[invalid-name]


class DuckDBAdapter(SyncDriverAdapterProtocol):
    """Implements a duckdb backend for aiosql."""

    def process_sql(self, query_name: str, op_type: "SQLOperationType", sql: str) -> str:
        """Preprocess SQL query."""
        return sql

    def _cursor(self, conn: "DuckDBPyConnection") -> "DuckDBPyConnection":
        """Get a cursor from a connection."""
        return conn.cursor()

    def select(
        self,
        conn: "DuckDBPyConnection",
        query_name: str,
        sql: str,
        parameters: Union[List, Dict],
        record_class: Optional[RecordClassType] = None,
    ) -> list[Any]:
        try:
            cur = self._cursor(conn)
            cur.execute(sql, parameters)
            results = cur.fetchall()

            if record_class is None and len(results) > 0:
                column_names = [c[0] for c in cur.description]  # type: ignore[attr-defined]
                results = [dict(zip(column_names, row)) for row in results]
            if record_class is not None and len(results) > 0:
                column_names = [c[0] for c in cur.description]  # type: ignore[attr-defined]
                results = [record_class(**dict(zip(column_names, row))) for row in results]

        finally:
            cur.close()
        return results

    def select_one(
        self,
        conn: "DuckDBPyConnection",
        query_name: str,
        sql: str,
        parameters: Union[List, Dict],
        record_class: Optional[Any] = None,
    ) -> Optional[Any]:
        cur = self._cursor(conn)
        try:
            cur.execute(sql, parameters)
            result = cur.fetchone()
            if result is not None and record_class is None:
                column_names = [c[0] for c in cur.description]  # type: ignore[attr-defined]
                result = dict(zip(column_names, result))  # type: ignore[call-overload]
            if result is not None and record_class is not None:
                column_names = [c[0] for c in cur.description]  # type: ignore[attr-defined]
                result = record_class(**dict(zip(column_names, result)))  # type: ignore[call-overload]
        finally:
            cur.close()
        return result

    def select_value(
        self, conn: "DuckDBPyConnection", query_name: str, sql: str, parameters: Union[List, Dict]
    ) -> "Optional[Union[float, int, str, datetime]]":
        cur = self._cursor(conn)
        try:
            cur.execute(sql, parameters)
            result = cur.fetchone()
        finally:
            cur.close()
        return result[0] if result else None  # type: ignore[index]

    @contextmanager
    def select_cursor(
        self, conn: "DuckDBPyConnection", query_name: str, sql: str, parameters: Union[List, Dict]
    ) -> Iterator["DuckDBPyConnection"]:
        cur = self._cursor(conn)
        cur.execute(sql, parameters)
        try:
            yield cur
        finally:
            cur.close()

    def insert_update_delete(
        self, conn: "DuckDBPyConnection", query_name: str, sql: str, parameters: Union[List, Dict]
    ) -> int:
        """Insert Update Delete

        This enhancement adds support for returning the row count for duckdb.  By default, DuckDB always returns -1
        """
        cur = self._cursor(conn)
        cur.execute(sql, parameters)
        rc = getattr(cur, "rowcount", -1)
        # We leave the original behavior in and only call the override if we get -1.
        # This is to ensure compatibility in-case it's added in the future for DuckDB
        if rc == -1:
            result = cur.fetchone()
            rc = result[0] if result else rc  # type: ignore[index]
        cur.close()
        return cast("int", rc)

    def insert_update_delete_many(
        self,
        conn: "DuckDBPyConnection",
        query_name: str,
        sql: str,
        parameters: Union[List, Dict],
    ) -> int:
        cur = self._cursor(conn)
        cur.executemany(sql, parameters)
        rc = getattr(cur, "rowcount", -1)
        # We leave the original behavior in and only call the override if we get -1.
        # This is to ensure compatibility in-case it's added in the future for DuckDB
        if rc == -1:
            result = cur.fetchone()
            rc = result[0] if result else rc  # type: ignore[index]
        cur.close()
        return cast("int", rc)

    def insert_returning(
        self, conn: "DuckDBPyConnection", query_name: str, sql: str, parameters: Union[List, Dict]
    ) -> Optional[Any]:
        # very similar to select_one but the returned value
        cur = self._cursor(conn)
        cur.execute(sql, parameters)
        res = cur.fetchone()
        cur.close()
        return res[0] if res and len(res) == 1 else res  # type: ignore[index, arg-type]

    def execute_script(self, conn: "DuckDBPyConnection", sql: str) -> str:
        cur = self._cursor(conn)
        cur.execute(sql)
        msg = getattr(cur, "statusmessage", "DONE")
        cur.close()
        return cast("str", msg)


class BigQueryAdapter(SyncDriverAdapterProtocol):
    """Implements a Google BigQuery backend for aiosql."""
