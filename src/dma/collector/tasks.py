from __future__ import annotations

from sys import version_info
from typing import TYPE_CHECKING, Literal, cast

import polars as pl
from rich.padding import Padding
from rich.table import Table
from sqlalchemy.ext.asyncio import AsyncSession

from dma.collector.queries import provide_canonical_queries, provides_collection_queries
from dma.lib.db.base import get_engine
from dma.lib.db.local import get_duckdb_connection

if TYPE_CHECKING:
    from pathlib import Path

    import duckdb
    from rich.console import Console

    from dma.collector.query_manager import CanonicalQueryManager, CollectionQueryManager

if version_info < (3, 10):  # pragma: nocover
    from dma.utils import anext_ as anext  # noqa: A001


async def readiness_check(
    console: Console,
    db_type: Literal["mysql", "postgres", "mssql", "oracle"],
    username: str,
    password: str,
    hostname: str,
    port: int,
    database: str,
    # pkey: str,
    # dma_source_id: str,
    # dma_manual_id: str,
    working_path: Path | None = None,
) -> None:
    """Assess the migration readiness for a Database for Database Migration Services"""
    async_engine = get_engine(db_type, username, password, hostname, port, database)
    with get_duckdb_connection(working_path) as local_db:
        async with AsyncSession(async_engine) as db_session:
            collection_manager = cast("CollectionQueryManager", await anext(provides_collection_queries(db_session)))
            pipeline_manager = next(provide_canonical_queries(local_db))
            # collect data
            _collection = await collection_manager.execute_collection_queries()
            _extended_collection = await collection_manager.execute_extended_collection_queries()
            # import data locally
            local_db = import_data_to_local_db(local_db, _collection)
            local_db = import_data_to_local_db(local_db, _extended_collection)

            # transform data
            local_db = execute_local_db_pipeline(local_db, pipeline_manager)
            console.print(Padding("COLLECTION SUMMARY", 1, style="bold", expand=True), width=80)
            # print summary
            print_summary(console, local_db, pipeline_manager, db_type)


def import_data_to_local_db(
    local_db: duckdb.DuckDBPyConnection, data: dict[str, list[dict]]
) -> duckdb.DuckDBPyConnection:
    """Loads Dictionary of type dict[str,list[dict]] to a DuckDB connection."""
    for table_name, table_data in data.items():
        if len(table_data) > 0:
            local_db.register(table_name, pl.from_dicts(table_data, infer_schema_length=10000))
    return local_db


def execute_local_db_pipeline(
    local_db: duckdb.DuckDBPyConnection, manager: CanonicalQueryManager
) -> duckdb.DuckDBPyConnection:
    """Transforms Loaded Data into the Canonical Model Tables."""
    manager.execute_transformation_queries()
    manager.execute_assessment_queries()
    return local_db


def print_summary(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    _manager: CanonicalQueryManager,
    _db_type: Literal["mysql", "postgres", "mssql", "oracle"],
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    if _db_type == "postgres":
        _print_summary_postgres(console, local_db, _manager)
    elif _db_type == "mysql":
        _print_summary_mysql(console, local_db, _manager)
    else:
        msg = f"{_db_type} is not implemented."
        raise NotImplementedError(msg)


def _print_summary_postgres(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    _manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    calculated_metrics = local_db.sql(
        """
            select metric_category, metric_name, metric_value
            from collection_postgres_calculated_metrics
        """,
    ).fetchall()
    count_table = Table(show_edge=False)
    count_table.add_column("Metric Category", justify="right", style="green")
    count_table.add_column("Metric", justify="right", style="green")
    count_table.add_column("Value", justify="right", style="green")

    for row in calculated_metrics:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)


def _print_summary_mysql(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    _manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    calculated_metrics = local_db.sql(
        """
            select variable_category, variable_name, variable_value
            from collection_mysql_config
        """,
    ).fetchall()
    count_table = Table(show_edge=False)
    count_table.add_column("Variable Category", justify="right", style="green")
    count_table.add_column("Variable", justify="right", style="green")
    count_table.add_column("Value", justify="right", style="green")

    for row in calculated_metrics:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)
