from __future__ import annotations

import logging
import re
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

rds_minor_version_support_map = {
	9.6: 10,
	10:  5,
	11:  1,
	12:  2,
}

# Matches version numbers of both old (Eg: 9.6.2) and new formats (Eg: 10.2).
version_regex = re.compile(r'(?P<version>\d+\.\d+(\.\d+)?).*')

def get_db_minor_version(db_version: string) -> int:
    version_match = version_regex.match(db_version)
    if not version_match:
        return -1
    version = version_match.group('version')
    split = version.split('.')
    if db_version.startswith('9'):
        if len(split) > 2:
            return int(split[2])
    elif len(split) > 1:
        return int(split[1])
    return -1

def get_db_major_version(db_version: string) -> float:
    index = db_version.find("beta")
    if index != -1:
        db_version = db_version[:index] + '.0'
    
    split = db_version.split('.')
    if db_version.startswith('9'):
        db_version = '.'.join(split[:2])
    else:
        db_version = '.'.join(split[:1])
    return float(db_version)

def rds_min_version_check_fail(version, major_version: string) -> bool:
    minor_version = get_db_minor_version(version)
    if minor_version == -1:
        logging.error("couldn't parse the version %s to fetch the minor version number", version)
        return False
    supported_min_version = rds_minor_version_support_map.get(major_version)
    if supported_min_version and minor_version < supported_min_version:
        return True
    return False

def version_check(console: Console,
    db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager) -> None:
    queries = manager.queries
    version = queries.get_pg_version(db)[0]
    major = get_db_major_version(version)
    is_rds = queries.is_source_rds(db)[0]
    min_major_version = 9.4
    if is_rds:
        min_major_version = 9.6
        if rds_min_version_check_fail(version, major):
            queries.insert_readiness_check(db, severity="ERROR", assessment_type="INCOMPATIBLE_DATABASE_VERSION", info=f"Source RDS database server has unsupported minor version: ({version})")

    if major not in db_type_map or major < min_major_version:
        queries.insert_readiness_check(db, severity="ERROR", assessment_type="INCOMPATIBLE_DATABASE_VERSION", info=f"Replication from source database server ({version}) is not supported")


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
            select severity, assessment_type, info
            from alloydb_readiness_check_summary
        """,
    ).fetchall()
    count_table = Table(show_edge=False, width=80)
    count_table.add_column("Severity", justify="right", style="green")
    count_table.add_column("Assessment Type", justify="right", style="green")
    count_table.add_column("Info", justify="right", style="green")

    for row in alloydb_readiness_check_summary:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)
