from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Literal

from rich.table import Table

from dma.collector.workflows.readiness_check._postgres.constants import (
    ALLOYDB_SUPPORTED_COLLATIONS,
    CLOUDSQL_SUPPORTED_COLLATIONS,
    DB_TYPE_MAP,
    RDS_MINOR_VERSION_SUPPORT_MAP,
)
from dma.collector.workflows.readiness_check._postgres.helpers import get_db_major_version, get_db_minor_version
from dma.collector.workflows.readiness_check.base import (
    ReadinessCheck,
    ReadinessCheckExecutor,
    ReadinessCheckTargetConfig,
)
from dma.lib.exceptions import ApplicationError

if TYPE_CHECKING:
    from rich.console import Console


@dataclass
class PostgresReadinessCheckTargetConfig(ReadinessCheckTargetConfig):
    db_variant: Literal["CLOUDSQL", "ALLOYDB"]
    supported_collations: set[str]
    supported_extensions: set[str]
    minimum_supported_rds_major_version: float
    db_version_map: dict[float, str] = field(default_factory=lambda: DB_TYPE_MAP)
    rds_minor_version_support_map: dict[float, int] = field(default_factory=lambda: RDS_MINOR_VERSION_SUPPORT_MAP)


POSTGRES_RULE_CONFIGURATIONS: list[PostgresReadinessCheckTargetConfig] = [
    PostgresReadinessCheckTargetConfig(
        db_type="POSTGRES",
        db_variant="ALLOYDB",
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=15,
        supported_collations=ALLOYDB_SUPPORTED_COLLATIONS,
        supported_extensions=set(),
    ),
    PostgresReadinessCheckTargetConfig(
        db_type="POSTGRES",
        db_variant="CLOUDSQL",
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=15,
        supported_collations=CLOUDSQL_SUPPORTED_COLLATIONS,
        supported_extensions=set(),
    ),
]


class PostgresReadinessCheckExecutor(ReadinessCheckExecutor):
    def __init__(
        self,
        console: Console,
        readiness_check: ReadinessCheck,
        rule_config: list[PostgresReadinessCheckTargetConfig] | None = None,
    ) -> None:
        self.rule_config = rule_config or POSTGRES_RULE_CONFIGURATIONS
        super().__init__(console=console, readiness_check=readiness_check)

    def execute(self) -> None:
        """Execute postgres checks"""
        self._collation_check()
        self._version_check()

    def _collation_check(self) -> None:
        rule_code = "COLLATION"
        result = self.local_db.sql(
            "select distinct database_collation from collection_postgres_database_details"
        ).fetchmany()
        collations = {row[0] for row in result}
        for c in self.rule_config:
            unsupported_collations = collations.difference(c.supported_collations)
            for unsupported_collation in unsupported_collations:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Unsupported collation: {unsupported_collation} is not supported on this instance",
                )
            if len(unsupported_collations) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "All utilized collations are supported.",
                )

    def _version_check(self) -> None:
        rule_code = "DATABASE_VERSION"
        if self.db_version is None:
            msg = "Database version was not set."
            raise ApplicationError(msg)
        detected_major_version = get_db_major_version(self.db_version)
        detected_minor_version = get_db_minor_version(self.db_version)
        is_rds = self._is_rds()
        for c in self.rule_config:
            if is_rds:
                supported_minor_version = c.rds_minor_version_support_map.get(detected_major_version)
                if supported_minor_version and detected_minor_version < supported_minor_version:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        "ERROR",
                        f"Source RDS database server has unsupported minor version: ({detected_minor_version})",
                    )
                else:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        "PASS",
                        f"Version {self.db_version} is supported.  Please ensure that you selected a version that meets or exceeds version {detected_major_version!s}.",
                    )
            elif (
                detected_major_version not in c.db_version_map
                or detected_major_version < c.minimum_supported_major_version
            ):
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Replication from source database server ({self.db_version}) is not supported",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    f"Version {self.db_version} is supported.  Please ensure that you selected a version that meets or exceeds version {detected_major_version!s}.",
                )

    def print_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        # self._print_database_details()  # noqa: ERA001
        self._print_readiness_check_summary()

    def _print_database_details(
        self,
    ) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        results = self.local_db.sql(
            """
                select metric_category, metric_name, metric_value
                from collection_postgres_calculated_metrics
            """,
        ).fetchall()
        count_table = Table(min_width=80)
        count_table.add_column("Variable Category", justify="right", style="green")
        count_table.add_column("Variable", justify="right", style="green")
        count_table.add_column("Value", justify="right", style="green")
        for row in results:
            count_table.add_row(*[str(col) for col in row])
        self.console.print(count_table)

    def _print_readiness_check_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        results = self.local_db.sql(
            """
                select severity, rule_code, info
                from readiness_check_summary
                where migration_target = 'ALLOYDB'
            """,
        ).fetchall()
        count_table = Table(min_width=80)
        count_table.add_column("Severity", justify="right")
        count_table.add_column("Rule Code", justify="left")
        count_table.add_column("Info", justify="left")

        for row in results:
            count_table.add_row(
                f"[bold green]{row[0]}[/]" if row[0] == "PASS" else f"[bold red]{row[0]}[/]",
                f"[bold]{row[1]}[/]",
                row[2],
            )
        self.console.print(count_table)

    # helper methods
    def _is_rds(self) -> bool:
        result = self.local_db.sql("""
            select case when a.cnt > 0 then true else false end as is_rds
            from (select count() as cnt from collection_postgres_extensions where extension_owner='rdsadmin' AND is_super_user) a
        """).fetchone()
        return bool(result[0] > 0) if result is not None else False