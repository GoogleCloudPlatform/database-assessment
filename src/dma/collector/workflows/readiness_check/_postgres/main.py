from __future__ import annotations

import logging
from dataclasses import dataclass
from typing import TYPE_CHECKING, Final, Literal

import duckdb
from rich.table import Table

from dma.collector.workflows.readiness_check._postgres.constants import (
    ALLOYDB_SUPPORTED_COLLATIONS,
    CLOUDSQL_SUPPORTED_COLLATIONS,
)
from dma.collector.workflows.readiness_check._postgres.helpers import get_db_major_version, get_db_minor_version
from dma.collector.workflows.readiness_check.base import ReadinessCheckTargetConfig

if TYPE_CHECKING:
    import duckdb
    from aiosql.queries import Queries
    from rich.console import Console

    from dma.collector.query_managers import CanonicalQueryManager


RDS_MINOR_VERSION_SUPPORT_MAP: Final[dict[float, int]] = {
    9.6: 10,
    10: 5,
    11: 1,
    12: 2,
}


@dataclass
class PostgresReadinessCheckTargetConfig(ReadinessCheckTargetConfig):
    db_variant: Literal["cloudsql", "alloydb"]
    supported_collations: set[str]
    supported_extensions: set[str]


POSTGRES_RULE_CONFIGURATIONS: list[PostgresReadinessCheckTargetConfig] = [
    PostgresReadinessCheckTargetConfig(
        db_type="postgres",
        db_variant="alloydb",
        minimum_supported_major_version=9.4,
        maximum_supported_major_version=15,
        supported_collations=ALLOYDB_SUPPORTED_COLLATIONS,
        supported_extensions=set(),
    ),
    PostgresReadinessCheckTargetConfig(
        db_type="postgres",
        db_variant="cloudsql",
        minimum_supported_major_version=9.4,
        maximum_supported_major_version=15,
        supported_collations=CLOUDSQL_SUPPORTED_COLLATIONS,
        supported_extensions=set(),
    ),
]


def rds_min_version_check_fail(version: str, major_version: float) -> bool:
    minor_version = get_db_minor_version(version)
    if minor_version == -1:
        logging.error("couldn't parse the version %s to fetch the minor version number", version)
        return False
    supported_min_version = RDS_MINOR_VERSION_SUPPORT_MAP.get(major_version)
    return bool(supported_min_version and minor_version < supported_min_version)


def _version_check(db: duckdb.DuckDBPyConnection, queries: Queries, db_version: str) -> None:
    major = get_db_major_version(db_version)
    is_rds = queries.is_source_rds(db)[0]
    min_major_version = 9.4
    if is_rds:
        min_major_version = 9.6
        if rds_min_version_check_fail(version, major):
            queries.insert_readiness_check(
                db,
                severity="ERROR",
                assessment_type="INCOMPATIBLE_DATABASE_VERSION",
                info=f"Source RDS database server has unsupported minor version: ({db_version})",
            )

    if major not in db_type_map or major < min_major_version:
        queries.insert_readiness_check(
            db,
            severity="ERROR",
            assessment_type="INCOMPATIBLE_DATABASE_VERSION",
            info=f"Replication from source database server ({db_version}) is not supported",
        )


def _collation_check(console: Console, db: duckdb.DuckDBPyConnection, queries: Queries) -> None:
    place_holder = ",".join("?" for c in ALLOYDB_SUPPORTED_COLLATIONS)
    query = queries.verify_collation_support.sql % place_holder
    db.execute(query, ALLOYDB_SUPPORTED_COLLATIONS.supported_collations)


def execute_postgres_readiness_check(
    console: Console, local_db: duckdb.DuckDBPyConnection, manager: CanonicalQueryManager, db_version: str
) -> None:
    """Execute postgres assessments"""
    for variant_config in POSTGRES_RULE_CONFIGURATIONS:
        _version_check(console, local_db, manager.queries)
        _collation_check(console, local_db, manager.queries)


def print_summary_postgres(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    _print_database_details(console=console, local_db=local_db, manager=manager)
    _print_readiness_check_summary(console=console, local_db=local_db, manager=manager)


def _print_database_details(
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


def _print_readiness_check_summary(
    console: Console,
    local_db: duckdb.DuckDBPyConnection,
    manager: CanonicalQueryManager,
) -> None:
    """Print Summary of the Migration Readiness Assessment."""
    calculated_metrics = local_db.sql(
        """
            select severity, assessment_type, info
            from alloydb_readiness_check_summary
        """,
    ).fetchall()
    count_table = Table(show_edge=False, width=80)
    count_table.add_column("Severity", justify="right", style="green")
    count_table.add_column("Rule Type", justify="right", style="green")
    count_table.add_column("Info", justify="right", style="green")

    for row in calculated_metrics:
        count_table.add_row(*[str(col) for col in row])
    console.print(count_table)
