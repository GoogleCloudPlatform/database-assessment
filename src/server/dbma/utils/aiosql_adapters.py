# type: ignore
from aiosql.adapters.generic import GenericAdapter


class DuckDBAdapter(GenericAdapter):
    """Implements a duckdb backend for aiosql."""

    def insert_update_delete(self, conn, _query_name, sql, parameters):
        """Insert Update Delete

        This enhancement adds support for returning the row count for duckdb.  By default, DuckDB always returns -1
        """
        cur = self._cursor(conn)
        cur.execute(sql, parameters)
        rc = cur.rowcount if hasattr(cur, "rowcount") else -1
        # We leave the original behavior in and only call the override if we get -1.
        # This is to ensure compatibility in-case it's added in the future for DuckDB
        if rc == -1:
            result = cur.fetchone()
            rc = result[0] if result else -1
        cur.close()
        return rc

    def insert_update_delete_many(self, conn, _query_name, sql, parameters):
        cur = self._cursor(conn)
        cur.executemany(sql, parameters)
        rc = cur.rowcount if hasattr(cur, "rowcount") else -1
        # We leave the original behavior in and only call the override if we get -1.
        # This is to ensure compatibility in-case it's added in the future for DuckDB
        if rc == -1:
            result = cur.fetchone()
            rc = result[0] if result else -1
        cur.close()
        return rc


class BigQueryAdapter(GenericAdapter):
    """Implements a Google BigQuery backend for aiosql."""
