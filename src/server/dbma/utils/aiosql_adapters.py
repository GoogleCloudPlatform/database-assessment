from contextlib import contextmanager
from typing import TYPE_CHECKING, Iterator, Optional, Union, cast

from duckdb import DuckDBPyConnection

if TYPE_CHECKING:
    from datetime import datetime


class DuckDBAdapter:
    """Implements a duckdb backend for aiosql."""

    def process_sql(self, _query_name: str, _op_type, sql):
        """Preprocess SQL query."""
        return sql

    def _cursor(self, conn: DuckDBPyConnection):
        """Get a cursor from a connection."""
        return conn.cursor()

    def select(self, conn: DuckDBPyConnection, _query_name: str, sql, parameters, record_class=None) -> list[dict]:
        cur = self._cursor(conn)
        try:
            cur.execute(sql, parameters)
            results = cur.fetchall()
            if record_class is None and len(results) > 0:
                column_names = [c[0] for c in cur.description]
                results = [dict(zip(column_names, row)) for row in results]
            if record_class is not None and len(results) > 0:
                column_names = [c[0] for c in cur.description]
                results = [record_class(**dict(zip(column_names, row))) for row in results]

        finally:
            cur.close()
        return results

    def select_one(self, conn: DuckDBPyConnection, _query_name: str, sql, parameters, record_class=None) -> dict:
        cur = self._cursor(conn)
        try:
            cur.execute(sql, parameters)
            result = cur.fetchone()
            if result is not None and record_class is None:
                column_names = [c[0] for c in cur.description]
                result = dict(zip(column_names, result))
            if result is not None and record_class is not None:
                column_names = [c[0] for c in cur.description]
                result = record_class(**dict(zip(column_names, result)))
        finally:
            cur.close()
        return result

    def select_value(
        self, conn: DuckDBPyConnection, _query_name: str, sql, parameters
    ) -> "Optional[Union[float, int, str, datetime]]":
        cur = self._cursor(conn)
        try:
            cur.execute(sql, parameters)
            result = cur.fetchone()
        finally:
            cur.close()
        return result[0] if result else None

    @contextmanager
    def select_cursor(
        self, conn: DuckDBPyConnection, _query_name: str, sql, parameters
    ) -> Iterator[DuckDBPyConnection]:
        cur = self._cursor(conn)
        cur.execute(sql, parameters)
        try:
            yield cur
        finally:
            cur.close()

    def insert_update_delete(self, conn: DuckDBPyConnection, _query_name, sql, parameters) -> int:  # type: ignore[no-untyped-def]
        """Insert Update Delete

        This enhancement adds support for returning the row count for duckdb.  By default, DuckDB always returns -1
        """
        cur = self._cursor(conn)  # type: ignore[no-untyped-call]
        cur.execute(sql, parameters)
        rc = cur.rowcount if hasattr(cur, "rowcount") else -1
        # We leave the original behavior in and only call the override if we get -1.
        # This is to ensure compatibility in-case it's added in the future for DuckDB
        if rc == -1:
            result = cur.fetchone()
            rc = result[0] if result else -1
        cur.close()
        return cast("int", rc)

    def insert_update_delete_many(self, conn: DuckDBPyConnection, _query_name, sql, parameters) -> int:  # type: ignore[no-untyped-def]
        cur = self._cursor(conn)
        cur.executemany(sql, parameters)
        rc = cur.rowcount if hasattr(cur, "rowcount") else -1
        # We leave the original behavior in and only call the override if we get -1.
        # This is to ensure compatibility in-case it's added in the future for DuckDB
        if rc == -1:
            result = cur.fetchone()
            rc = result[0] if result else -1
        cur.close()
        return cast("int", rc)

    def insert_returning(self, conn: DuckDBPyConnection, _query_name, sql, parameters):
        # very similar to select_one but the returned value
        cur = self._cursor(conn)
        cur.execute(sql, parameters)
        res = cur.fetchone()
        cur.close()
        return res[0] if res and len(res) == 1 else res

    def execute_script(self, conn: DuckDBPyConnection, sql) -> str:
        cur = self._cursor(conn)
        cur.execute(sql)
        msg = cur.statusmessage if hasattr(cur, "statusmessage") else "DONE"
        cur.close()
        return cast("str", msg)


class BigQueryAdapter:
    """Implements a Google BigQuery backend for aiosql."""
