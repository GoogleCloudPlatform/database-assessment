import functools as ft
from typing import Any, Callable, Dict, List, Literal, Optional, Set, Type

import aiosql as sql
from aiosql.queries import Queries
from sqlalchemy.future import Engine, create_engine
from sqlalchemy.orm import sessionmaker

from dbma.utils.aiosql_adapters import BigQueryAdapter, DuckDBAdapter

__all__ = ["get_engine", "get_aiosql_adapter", "db_session_maker", "SQLManager", "SupportedEngines"]

SupportedEngines = Literal["duckdb", "bigquery"]


@ft.lru_cache(maxsize=3)
def get_engine(engine_type: SupportedEngines) -> Engine:
    """builds an engine for the specified database type"""
    if engine_type == "duckdb":
        return create_engine(url="duckdb:///:memory:", connect_args={"config": {"memory_limit": "500mb"}})

    if engine_type == "bigquery":
        return create_engine(url="bigquery://some-project/some-dataset")

    raise NotImplementedError("The specified engine is not implemented")


@ft.lru_cache(maxsize=3)
def get_aiosql_adapter(engine_type: SupportedEngines) -> Type[DuckDBAdapter] | Type[BigQueryAdapter]:
    """builds an engine for the specified database type"""
    if engine_type == "duckdb":
        return DuckDBAdapter

    if engine_type == "bigquery":
        return BigQueryAdapter

    raise NotImplementedError("The specified engine is not implemented")


@ft.lru_cache
def db_session_maker(engine_type: SupportedEngines) -> sessionmaker:
    engine = get_engine(engine_type)
    return sessionmaker(engine, expire_on_commit=False)


class SQLManager:
    """Hides database connection and queries in here.

    The class provides the DB-API 2.0 connection methods,
    and SQL execution methods from aiosql.
    """

    def __init__(
        self, engine_type: Literal["duckdb", "bigquery", "postgres"], sql_files_path: Optional[str] = None
    ) -> None:

        self.engine_type = engine_type
        self.engine = get_engine(engine_type)
        self.sql_files_path = sql_files_path
        self._queries: List[Queries] = []
        self._count: Dict[str, int] = {}
        self._available_queries: Set[str] = set()
        if sql_files_path:
            self.add_sql_from_path(sql_files_path)
        # last thing is to actually create the connection, which may fail
        self._db_session_factory = db_session_maker(engine_type)
        self._db_session = self.engine.raw_connection()

    def add_sql_from_path(self, fn: str) -> None:
        """Load queries from a file or directory."""
        self._create_fns(sql.from_path(fn, get_aiosql_adapter(self.engine_type)))

    def add_sql_from_str(self, qs: str) -> None:
        """Load queries from a string."""
        self._create_fns(sql.from_str(qs, get_aiosql_adapter(self.engine_type)))

    def cursor(self):  # type: ignore[no-untyped-def]
        """Get a cursor on the current connection."""
        return self._db_session.cursor()

    def commit(self) -> None:
        """Commit database transaction."""
        self._db_session.commit()

    def rollback(self) -> None:
        """Rollback database transaction."""
        self._db_session.rollback()  # type: ignore[attr-defined]

    def close(self) -> None:
        """Close underlying database connection."""
        self._db_session.close()

    def _call_fn(self, query: str, fn: Callable, *args: Any, **kwargs: Any) -> Any:
        """Forward method call to aiosql query"""
        self._count[query] += 1
        return fn(self._db_session, *args, **kwargs)

    def _create_fns(self, queries: Queries) -> None:
        """Create call forwarding to insert the database connection."""
        self._queries.append(queries)
        for q in queries.available_queries:
            f = getattr(queries, q)
            # we skip internal *_cursor attributes
            if callable(f):
                setattr(self, q, ft.partial(self._call_fn, q, f))
                self._available_queries.add(q)
                self._count[q] = 0

    def __str__(self) -> str:
        return f"Connection Manager for ({self.engine_type})"

    def __del__(self) -> None:
        if hasattr(self, "_db_session") and self._db_session:
            self.close()
