from __future__ import annotations

from sys import version_info
from typing import TYPE_CHECKING, Literal

import polars as pl
from rich.progress import Progress
from rich.table import Table
from sqlalchemy.ext.asyncio import AsyncSession

from dma.collector.queries import provide_canonical_queries, provides_collection_queries
from dma.lib.db.base import get_engine
from dma.lib.db.local import get_duckdb_connection

if TYPE_CHECKING:
    from pathlib import Path

    import duckdb
    from rich.console import Console

    from dma.collector.query_manager import CanonicalQueryManager

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
    with get_duckdb_connection(working_path) as local_db, Progress(console=console) as _progress:
        async with AsyncSession(async_engine) as db_session:
            collection_manager = await anext(provides_collection_queries(db_session))
            pipeline_manager = next(provide_canonical_queries(local_db))
            # collect data
            _collection = await collection_manager.execute_collection_queries()
            _extended_collection = await collection_manager.execute_extended_collection_queries()
            # import data locally
            local_db = import_data_to_local_db(local_db, _collection)
            local_db = import_data_to_local_db(local_db, _extended_collection)

            # transform data
            local_db = execute_local_db_pipeline(local_db, pipeline_manager)

            # print summary
            print_summary(console, local_db, pipeline_manager)


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
    console: Console, local_db: duckdb.DuckDBPyConnection, _manager: CanonicalQueryManager
) -> duckdb.DuckDBPyConnection:
    """Print Summary of the Migration Readiness Assessment."""
    calculated_metrics = local_db.sql(
        """
            select metric_category, metric_name, metric_value
            from collection_postgres_calculated_metrics
        """,
    ).fetchall()
    count_table = Table(title="Database Calculated Metrics Overview")
    count_table.add_column("Metric Category", justify="right", style="green")
    count_table.add_column("Metric", justify="right", style="green")
    count_table.add_column("Value", justify="right", style="green")

    for row in calculated_metrics:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)
    return local_db
