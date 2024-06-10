# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from __future__ import annotations

from dataclasses import dataclass, field
from typing import TYPE_CHECKING

from rich.table import Table

from dma.collector.workflows.readiness_check._mysql.constants import (
    DB_TYPE_MAP,
    RDS_MINOR_VERSION_SUPPORT_MAP,
)
from dma.collector.workflows.readiness_check._mysql.helpers import get_db_major_version
from dma.collector.workflows.readiness_check.base import (
    ReadinessCheck,
    ReadinessCheckExecutor,
    ReadinessCheckTargetConfig,
)

if TYPE_CHECKING:
    from rich.console import Console

    from dma.types import MySQLVariants


@dataclass
class MySQLReadinessCheckTargetConfig(ReadinessCheckTargetConfig):
    db_variant: MySQLVariants
    supported_plugins: set[str]
    minimum_supported_rds_major_version: float
    db_version_map: dict[float, str] = field(default_factory=lambda: DB_TYPE_MAP)
    rds_minor_version_support_map: dict[float, int] = field(default_factory=lambda: RDS_MINOR_VERSION_SUPPORT_MAP)


MYSQL_RULE_CONFIGURATIONS: list[MySQLReadinessCheckTargetConfig] = [
    MySQLReadinessCheckTargetConfig(
        db_type="MYSQL",
        db_variant="CLOUDSQL",
        minimum_supported_major_version=5.6,
        minimum_supported_rds_major_version=8.0,
        maximum_supported_major_version=8,
        supported_plugins=set(),
    ),
]


class MySQLReadinessCheckExecutor(ReadinessCheckExecutor):
    db_version: str

    def __init__(
        self,
        console: Console,
        readiness_check: ReadinessCheck,
        rule_config: list[MySQLReadinessCheckTargetConfig] | None = None,
    ) -> None:
        self.rule_config = rule_config or MYSQL_RULE_CONFIGURATIONS
        super().__init__(console=console, readiness_check=readiness_check)

    def execute(self) -> None:
        """Execute postgres checks"""
        self._check_version()
        self._check_plugins()

    def _check_version(self) -> None:
        rule_code = "DATABASE_VERSION"

        detected_major_version = get_db_major_version(self.db_version)
        for c in self.rule_config:
            if (
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

    def _check_plugins(self) -> None:
        rule_code = "PLUGINS"
        result = self.local_db.sql("select distinct plugin_name from collection_mysql_plugins").fetchmany()
        plugins = {row[0] for row in result}
        for c in self.rule_config:
            unsupported_plugins = plugins.difference(c.supported_plugins)
            for unsupported_plugin in unsupported_plugins:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Unsupported plugin: {unsupported_plugin} is not supported on this instance",
                )
            if len(unsupported_plugins) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "All utilized plugins are supported.",
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
                from collection_mysql_database_details
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
        db_variants: set[MySQLVariants] = {"CLOUDSQL"}

        def table_for_target(migration_target: MySQLVariants) -> None:
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
                    f"[bold green]{row[0]}[/]"
                    if row[0] == "PASS"
                    else f"[bold yellow]{row[0]}[/]"
                    if row[0] == "WARNING"
                    else f"[bold red]{row[0]}[/]",
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
            from (select count() as cnt from collection_mysql_plugins where plugin_name='rdsadmin') a
        """).fetchone()
        return bool(result[0] > 0) if result is not None else False
