from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from rich.table import Table

from dma.collector.workflows.readiness_check._postgres.constants import (
    ALLOYDB_SUPPORTED_COLLATIONS,
    ALLOYDB_SUPPORTED_EXTENSIONS,
    ALLOYDB_SUPPORTED_FDWS,
    CLOUDSQL_SUPPORTED_COLLATIONS,
    CLOUDSQL_SUPPORTED_EXTENSIONS,
    CLOUDSQL_SUPPORTED_FDWS,
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

    from dma.types import PostgresVariants


@dataclass
class PostgresReadinessCheckTargetConfig(ReadinessCheckTargetConfig):
    db_variant: PostgresVariants
    supported_collations: set[str]
    supported_extensions: set[str]
    supported_fdws: set[str]
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
        supported_extensions=ALLOYDB_SUPPORTED_EXTENSIONS,
        supported_fdws=ALLOYDB_SUPPORTED_FDWS,
    ),
    PostgresReadinessCheckTargetConfig(
        db_type="POSTGRES",
        db_variant="CLOUDSQL",
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=15,
        supported_collations=CLOUDSQL_SUPPORTED_COLLATIONS,
        supported_extensions=CLOUDSQL_SUPPORTED_EXTENSIONS,
        supported_fdws=CLOUDSQL_SUPPORTED_FDWS,
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
        self._check_version()
        self._check_collation()
        self._check_pglogical_installed()
        self._check_rds_logical_replication()
        self._check_wal_level()
        self._check_extensions()
        self._check_fdw()

    def _check_collation(self) -> None:
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

    def _check_version(self) -> None:
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

    def _check_pglogical_installed(self) -> None:
        rule_code = "PGLOGICAL_INSTALLED"
        if self.db_version is None:
            msg = "Database version was not set."
            raise ApplicationError(msg)
        result = self.local_db.sql(
            "select count(*) from collection_postgres_extensions where extension_name = 'pglogical'"
        ).fetchone()
        is_installed = result[0] > 0 if result is not None else False
        for c in self.rule_config:
            if is_installed:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    "The `pglogical` extension is not installed on the database.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "`pglogical` is installed on the database",
                )

    def _check_wal_level(self) -> None:
        rule_code = "WAL_LEVEL"
        if self.db_version is None:
            msg = "Database version was not set."
            raise ApplicationError(msg)
        wal_level = self._is_rds()
        for c in self.rule_config:
            if wal_level != "logical":
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f'The `wal_level` settings should be set to "logical" instead of "{wal_level}".',
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "`pglogical` is installed on the database`",
                )

    def _check_rds_logical_replication(self) -> None:
        rule_code = "RDS_LOGICAL_REPLICATION"
        if self.db_version is None:
            msg = "Database version was not set."
            raise ApplicationError(msg)
        detected_major_version = get_db_major_version(self.db_version)
        detected_minor_version = get_db_minor_version(self.db_version)
        is_rds = self._is_rds()
        if is_rds:
            for c in self.rule_config:
                supported_minor_version = c.rds_minor_version_support_map.get(detected_major_version)
                if supported_minor_version and detected_minor_version < supported_minor_version:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        "ERROR",
                        f'`rds.logical_replication` should be set to "on"` instead of ({detected_minor_version})',
                    )
                else:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        "PASS",
                        '`rds.logical_replication` was correctly set to "on"`',
                    )

    def _check_extensions(self) -> None:
        rule_code = "EXTENSIONS"
        if self.db_version is None:
            msg = "Database version was not set."
            raise ApplicationError(msg)
        result = self.local_db.sql("select distinct extension_name from collection_postgres_extensions").fetchmany()
        extensions = {row[0] for row in result}
        for c in self.rule_config:
            unsupported_extensions = extensions.difference(c.supported_extensions)
            for unsupported_extension in unsupported_extensions:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Unsupported extensions: {unsupported_extension} is not supported on this instance",
                )
            if len(unsupported_extensions) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "All utilized collations are supported.",
                )

    def _check_fdw(self) -> None:
        rule_code = "FDWS"
        if self.db_version is None:
            msg = "Database version was not set."
            raise ApplicationError(msg)
        result = self.local_db.sql("""
            select foreign_data_wrapper_name as fdw_name, count(distinct table_schema || table_name) as table_count
            from collection_postgres_table_details
            where foreign_data_wrapper_name is not null
            group by foreign_data_wrapper_name
        """).fetchmany()
        fdws = {row[0] for row in result}
        fdw_table_count = {row[1] for row in result}
        for c in self.rule_config:
            unsupported_fdws = fdws.difference(c.supported_fdws)
            for unsupported_fdw, table_count in zip(unsupported_fdws, fdw_table_count):
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f'Unsupported FDW: detected {table_count} "{unsupported_fdw}" foreign tables.',
                )
            if len(unsupported_fdws) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "All utilized foreign data wrappers are supported.",
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
        db_variants: set[PostgresVariants] = {"ALLOYDB", "CLOUDSQL"}

        def table_for_target(migration_target: PostgresVariants) -> None:
            results = self.local_db.execute(
                """
                    select severity, rule_code, info
                    from readiness_check_summary
                    where migration_target = ?
                """,
                [migration_target],
            ).fetchall()
            count_table = Table(
                min_width=80, title=f"{migration_target} Compatibility", leading=5, title_justify="left"
            )
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

        for v in db_variants:
            table_for_target(v)

    # helper methods
    def _is_rds(self) -> bool:
        result = self.local_db.sql("""
            select case when a.cnt > 0 then true else false end as is_rds
            from (select count() as cnt from collection_postgres_extensions where extension_owner='rdsadmin' AND is_super_user) a
        """).fetchone()
        return bool(result[0] > 0) if result is not None else False
