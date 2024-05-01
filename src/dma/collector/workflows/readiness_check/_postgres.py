from __future__ import annotations

import string
from typing import TYPE_CHECKING

import duckdb
from rich.table import Table

if TYPE_CHECKING:
    import duckdb
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager

db_type_map = {
	9.4: "POSTGRES_9_4",
	9.5: "POSTGRES_9_5",
	9.6: "POSTGRES_9_6",
	10:  "POSTGRES_10",
    11:  "POSTGRES_11",
	12:  "POSTGRES_12",
	13:  "POSTGRES_13",
	14:  "POSTGRES_14",
	15:  "POSTGRES_15",
}

def get_db_major_version(db_version: string) -> float:
    index = db_version.find("beta")
    if index != -1:
        db_version = db_version[:index] + ".0"
    
    split = db_version.split(".")
    if db_version.startswith("9"):
        db_version = '.'.join(split[:2])
    else:
        db_version = '.'.join(split[:1])
    return float(db_version)

def version_check(console: Console,
    db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager) -> None:
    queries = manager.queries
    version = queries.get_pg_version(db)
    major = get_db_major_version(version[0])
    if major < 9.4:
        queries.insert_readiness_check(db, severity="ERROR", info="Replication from postgres source database server < version 9.4 to AlloyDB is not supported")

def execute_postgres_assessment(console: Console,
    local_db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager) -> None:
    """Execute postgress assessments"""
    version_check(console, local_db, manager)

def print_summary_postgres(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    summary_table = Table(show_edge=False, width=80)
    print_database_details(console=console, local_db=local_db, manager=manager)
    console.print(summary_table)


def print_database_details(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    calculated_metrics = local_db.sql(
        """
            select metric_category, metric_name, metric_value
            from collection_postgres_calculated_metrics
        """,
    ).fetchall()
    count_table = Table(show_edge=False, width=80)
    count_table.add_column("Variable Category", justify="right", style="green")
    count_table.add_column("Variable", justify="right", style="green")
    count_table.add_column("Value", justify="right", style="green")

    for row in calculated_metrics:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)

    alloydb_readiness_check_summary = local_db.sql(
        """
            select severity, info
            from alloydb_readiness_check_summary
        """,
    ).fetchall()
    count_table = Table(show_edge=False, width=80)
    count_table.add_column("Severity", justify="right", style="green")
    count_table.add_column("Info", justify="right", style="green")

    for row in alloydb_readiness_check_summary:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)
