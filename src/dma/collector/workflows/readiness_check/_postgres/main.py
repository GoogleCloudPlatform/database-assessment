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
from dma.collector.workflows.readiness_check.base import ReadinessCheck, ReadinessCheckTargetConfig

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
    minimum_supported_rds_major_version: str


POSTGRES_RULE_CONFIGURATIONS: list[PostgresReadinessCheckTargetConfig] = [
    PostgresReadinessCheckTargetConfig(
        db_type="postgres",
        db_variant="alloydb",
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=15,
        supported_collations=ALLOYDB_SUPPORTED_COLLATIONS,
        supported_extensions=set(),
    ),
    PostgresReadinessCheckTargetConfig(
        db_type="postgres",
        db_variant="cloudsql",
        minimum_supported_major_version=9.4, minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=15,
        supported_collations=CLOUDSQL_SUPPORTED_COLLATIONS,
        supported_extensions=set(),
    ),
]


class PostgresReadinessCheck:
    def __init__(
        self,
        console: Console,
        readiness_check: ReadinessCheck,
        rule_config: list[PostgresReadinessCheckTargetConfig] | None = None,
    ) -> None:
        self.console = console
        self.readiness_check = readiness_check
        self.local_db = readiness_check.local_db
        self.canonical_query_manager = readiness_check.canonical_query_manager
        self.db_version = readiness_check.db_type
        self.rule_config = rule_config or POSTGRES_RULE_CONFIGURATIONS

    def execute(self) -> None:
        """Execute postgres checks"""
        self._collation_check()

    def save_rule_result(
        self,
        migration_target: Literal["cloudsql", "alloydb"],
        rule_code: str,
        severity: Literal["error", "warning", "info", "pass"],
        message: str,
    ) -> None:
        self.local_db.execute(
            "insert into readiness_check_summary(migration_target, rule_code, severity, message) values (?,?,?,?)",
            [migration_target, rule_code, severity, message],
        )

    def _collation_check(self) -> None:
        rule_code = "UNSUPPORTED_COLLATION"
        collations = self.canonical_query_manager.select(
            "select distinct database_collation from collection_postgres_database_details"
        )
        collations = {row['database_collation'] for row in collations}
        for c in self.rule_config:
            unsupported_collations = set(collations).difference(c.supported_collations)
            for unsupported_collation in unsupported_collations:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "error",
                    f"Unsupported collation: {unsupported_collation} is not supported on this instance",
                )
            if len(unsupported_collations) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "pass",
                    "All utilized collations are supported.",
                )

    def _is_rds(self) -> bool:
        result = self.canonical_query_manager.select_one_value("""
            select case when a.cnt > 0 then true else false end as is_rds
            from (select count() as cnt from collection_postgres_extensions where extension_owner='rdsadmin' AND is_super_user) a
        """)
        return bool(result > 0)

    def __version_check_rds(version: str, major_version: float) -> bool:
        minor_version = get_db_minor_version(version)
        if minor_version == -1:
            logging.error("couldn't parse the version %s to fetch the minor version number", version)
            return False
        supported_min_version = RDS_MINOR_VERSION_SUPPORT_MAP.get(major_version)
        return bool(supported_min_version and minor_version < supported_min_version)

    def _version_check(self) -> None:
        major = get_db_major_version(self.db_version)
        is_rds = self._is_rds()
        for c in self.rule_config:
            if is_rds:
                if
                self._version_check_rds()

            else:

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


def rds_min_version_check_fail(version: str, major_version: float) -> bool:
    minor_version = get_db_minor_version(version)
    if minor_version == -1:
        logging.error("couldn't parse the version %s to fetch the minor version number", version)
        return False
    supported_min_version = RDS_MINOR_VERSION_SUPPORT_MAP.get(major_version)
    return bool(supported_min_version and minor_version < supported_min_version)


def _version_check(console: Console, db: duckdb.DuckDBPyConnection, queries: Queries, db_version: str) -> None:
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


class ReadinessCheckReport:

    def print_summary_postgres(
        console: Console,
        local_db: duckdb.DuckDBPyConnection,
        manager: CanonicalQueryManager,
    ) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        self._print_database_details()
        self._print_readiness_check_summary()

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
