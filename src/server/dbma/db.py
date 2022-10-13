import functools as ft
from typing import TYPE_CHECKING, Any, Callable, Dict, List, Literal, Optional, Set, Type, Union, cast

import aiosql as sql
import duckdb
from sqlalchemy.future import Engine, create_engine
from sqlalchemy.orm import sessionmaker

from dbma import log, storage
from dbma.config import settings
from dbma.utils import file_helpers as helpers
from dbma.utils.aiosql_adapters import BigQueryAdapter, DuckDBAdapter

if TYPE_CHECKING:
    from pathlib import Path

    from aiosql.queries import Queries
    from duckdb import DuckDBPyConnection
    from pyarrow.lib import Table as ArrowTable

    from dbma.transformer.schemas import AdvisorExtract

__all__ = ["get_engine", "get_aiosql_adapter", "db_session_maker", "SQLManager", "SupportedEngines"]

SupportedEngines = Literal["duckdb", "bigquery"]

logger = log.get_logger()


@ft.lru_cache(maxsize=3)
def get_engine(engine_type: SupportedEngines) -> "Engine":
    """builds an engine for the specified database type"""
    if engine_type == "duckdb":
        return create_engine(
            url=f"duckdb:///{settings.duckdb_path}", connect_args={"config": {"memory_limit": "500mb"}}
        )

    if engine_type == "bigquery":
        return create_engine(url=f"bigquery://{settings.google_project_id}/{settings.bigquery_dataset}")

    raise NotImplementedError("The specified engine is not implemented")


@ft.lru_cache(maxsize=3)
def get_aiosql_adapter(engine_type: SupportedEngines) -> "Union[Type[DuckDBAdapter], Type[BigQueryAdapter]]":
    """builds an engine for the specified database type"""
    if engine_type == "duckdb":
        return DuckDBAdapter

    if engine_type == "bigquery":
        return BigQueryAdapter

    raise NotImplementedError("The specified adapter is not implemented")


@ft.lru_cache
def db_session_maker(engine_type: SupportedEngines) -> sessionmaker:
    engine = get_engine(engine_type)
    return sessionmaker(engine, expire_on_commit=False)


class SQLManager:
    """Hides database connection and queries in here.

    The class provides the DB-API 2.0 connection methods,
    and SQL execution methods from aiosql.
    """

    def __init__(self, engine_type: SupportedEngines, sql_files_path: Optional[str] = None) -> None:

        self.engine_type = engine_type
        self.engine = get_engine(engine_type)
        self.sql_files_path = sql_files_path
        self._queries: "List[Queries]" = []
        self._count: Dict[str, int] = {}
        self._available_queries: Set[str] = set()
        if sql_files_path:
            self.add_sql_from_path(sql_files_path)
        # last thing is to actually create the connection, which may fail
        self._db_session_factory = db_session_maker(engine_type)
        self._db_session = self.engine.raw_connection()

    def add_sql_from_path(self, fn: str) -> None:
        """Load queries from a file or directory."""
        self._create_fns(sql.from_path(fn, cast("str", get_aiosql_adapter(self.engine_type))))

    def add_sql_from_str(self, qs: str) -> None:
        """Load queries from a string."""
        self._create_fns(sql.from_str(qs, cast("str", get_aiosql_adapter(self.engine_type))))

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

    @property
    def transform_scripts(self) -> list[str]:
        """Get transformation scripts"""
        return sorted([q for q in self._available_queries if q.startswith("transform")])

    def execute_transformation_scripts(self, advisor_extract: "AdvisorExtract") -> None:
        """


        Returns:
            _type_: _description_
        """
        for _, file_name in advisor_extract.files.dict(exclude_unset=True, exclude_none=True).items():
            for script in self.transform_scripts:
                fn = getattr(self, script)
                fn(str(file_name.absolute()), advisor_extract.files.delimiter)

    @property
    def load_scripts(self) -> list[str]:
        """Get transformation scripts"""
        return sorted([q for q in self._available_queries if q.startswith("load")])

    def execute_load_scripts(self, advisor_extract: "AdvisorExtract") -> None:
        """Execute load scripts

        Accepts a collection and runs the SQL load scripts against it.

        Args:
            advisor_extract (AdvisorExtract): The collection of Advisor extract files
        """
        for file_type, file_name in advisor_extract.files.dict(exclude_unset=True, exclude_none=True).items():
            logger.info("delimiter is %s", advisor_extract.files.delimiter)
            has_load_fn = hasattr(self, f"load_{file_type}")
            if not has_load_fn:
                logger.warning("... [bold yellow] Could not find a load procedure for %s.", file_type)
            if file_name.stat().st_size > 0:
                fn = getattr(self, f"load_{file_type}")
                rows_loaded = fn(str(file_name.absolute()), advisor_extract.files.delimiter)
                logger.info("... %s  [green bold]SUCCESS[/] [%s rows(s)]", file_type, rows_loaded)

            else:
                logger.info("... %s  [dim bold]SKIPPED[/] [empty file]", file_type)

    @property
    def pre_processing_scripts(self) -> list[str]:
        """Get transformation scripts

        Returns a sorted list of available commands loaded from the SQL files

        """
        return sorted([q for q in self._available_queries if q.startswith("pre")])

    def execute_pre_processing_scripts(self) -> None:
        """


        Returns:
            _type_: _description_
        """
        for script in self.pre_processing_scripts:
            getattr(self, script)()

    def _call_fn(self, query: str, fn: Callable, *args: Any, **kwargs: Any) -> Any:
        """Forward method call to aiosql query"""
        self._count[query] += 1
        return fn(self._db_session, *args, **kwargs)

    def _create_fns(self, queries: "Queries") -> None:
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
        self.close()


class CSVTransformer:
    """Transforms a CSV to various formats"""

    def __init__(self, file_path: "Path", delimiter: str = "|", has_headers: bool = True, skip_rows: int = 0) -> None:
        self.file_path = file_path
        self.delimiter = delimiter
        self.has_headers = has_headers
        self.skip_rows = skip_rows
        self.local_db = duckdb.connect()
        self.script_version = helpers.get_version_from_file(file_path)
        self.db_version = helpers.get_db_version_from_file(file_path)
        self.collection_key = helpers.get_collection_key_from_file(file_path)
        self.collection_id = helpers.get_collection_id_from_key(self.collection_key)

    def to_arrow_table(self, chunk_size: int = 1000000) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.arrow(chunk_size)

    def to_parquet(self, output_path: str) -> None:
        """Converts the CSV to an arrow table"""
        storage.engine.fs.auto_mkdir = True
        file = f"{self.file_path.parent}/{self.file_path.stem}.parquet"
        # nosec
        query = f"""
        --begin-sql
            COPY (
            select * from read_csv_auto(?, delim = ?, header = ?)
            ) TO '{file}' (FORMAT 'parquet')
        --end-sql
        """
        self.local_db.execute(
            query,
            [
                str(self.file_path),
                self.delimiter,
                self.has_headers,
            ],
        )
        storage.engine.fs.put(file, f"{output_path}/{self.collection_id}")

    def to_df(self) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.df()

    def _select_data(self) -> "DuckDBPyConnection":
        """Select the data from the CSV"""
        results = self.local_db.execute(
            """
            --begin-sql
            select * from read_csv_auto(?, delim = ?, header = ?)
            --end-sql
            """,
            [str(self.file_path), self.delimiter, self.has_headers],
        )
        return results
