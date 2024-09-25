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
from typing import TYPE_CHECKING, cast

from rich.table import Table

from dma.collector.util.postgres.helpers import get_db_major_version, get_db_minor_version
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
from dma.collector.workflows.readiness_check.base import (
    ReadinessCheck,
    ReadinessCheckExecutor,
    ReadinessCheckTargetConfig,
)

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
    extra_replication_subscriptions_required: int = 10


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
        extra_replication_subscriptions_required=10,
    ),
    PostgresReadinessCheckTargetConfig(
        db_type="POSTGRES",
        db_variant="CLOUDSQL",
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=16,
        supported_collations=CLOUDSQL_SUPPORTED_COLLATIONS,
        supported_extensions=CLOUDSQL_SUPPORTED_EXTENSIONS,
        supported_fdws=CLOUDSQL_SUPPORTED_FDWS,
        extra_replication_subscriptions_required=10,
    ),
]


class PostgresReadinessCheckExecutor(ReadinessCheckExecutor):
    db_version: str

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
        self._check_rds_logical_replication()
        self._check_wal_level()
        self._check_max_replication_slots()
        self._check_max_wal_senders_replication_slots()
        self._check_max_worker_processes()
        self._check_extensions()
        self._check_fdw()
        for db in self.get_all_dbs():
            is_pglogical_installed = self._check_pglogical_installed(db)
            self._check_privileges(db, is_pglogical_installed)
            if is_pglogical_installed:
                self._check_if_node_exists(db)

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

    def _check_pglogical_installed(self, db_name: str) -> bool:
        rule_code = "PGLOGICAL_INSTALLED"
        result = self.local_db.sql(
            query="select count(*) from collection_postgres_extensions where extension_name = 'pglogical' and database_name = $db_name",
            params={"db_name": db_name},
        ).fetchone()
        is_installed = result[0] > 0 if result is not None else False
        for c in self.rule_config:
            if not is_installed:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"The `pglogical` extension is not installed on the database {db_name}.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "`pglogical` is installed on the database.",
                )
        return is_installed

    def _check_pglogical_privileges(self, db_name: str) -> list[str]:
        result = self.local_db.sql(
            "select has_schema_usage_privilege, has_tables_select_privilege, has_local_node_select_privilege, has_node_select_privilege, has_node_interface_select_privilege from collection_postgres_pglogical_privileges where database_name = $db_name",
            params={"db_name": db_name},
        ).fetchone()
        errors: list[str] = []
        if result is None:
            errors.append("Empty result reading pglogical schema privileges for the user")
        else:
            if not result[0]:
                errors.append(f"user doesn't have USAGE privilege on schema pglogical for the database {db_name}")
            if not result[1]:
                errors.append(
                    f"user doesn't have SELECT privilege on table pglogical.tables for the database {db_name}"
                )
            if not result[2]:
                errors.append(
                    f"user doesn't have SELECT privilege on table pglogical.local_node for the database {db_name}"
                )
            if not result[3]:
                errors.append(f"user doesn't have SELECT privilege on table pglogical.node for the database {db_name}")
            if not result[4]:
                errors.append(
                    f"user doesn't have SELECT privilege on table pglogical.node_interface for the database {db_name}"
                )
        return errors

    def _check_if_node_exists(self, db_name: str) -> None:
        rule_code = "PGLOGICAL_NODE_ALREADY_EXISTS"
        result = self.local_db.sql(
            "select count(*) from collection_postgres_pglogical_provider_node where database_name = $db_name",
            params={"db_name": db_name},
        ).fetchone()
        node_exists = result[0] > 0 if result is not None else False
        for c in self.rule_config:
            if node_exists:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"pglogical provider node has already existed on database {db_name}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    "No existing pglogical provider node",
                )

    def check_user_obj_privileges(self, db_name: str) -> list[str]:
        errors: list[str] = []
        rows = self.local_db.sql(
            "select namespace_name from collection_postgres_user_schemas_without_privilege where database_name = $db_name",
            params={"db_name": db_name},
        ).fetchall()
        errors.extend(
            f"user doesn't have USAGE privilege on schema {row[0]} for the database {db_name}" for row in rows
        )

        rows = self.local_db.sql(
            "select schema_name, table_name from collection_postgres_user_tables_without_privilege where database_name = $db_name",
            params={"db_name": db_name},
        ).fetchall()
        errors.extend(
            f"user doesn't have SELECT privilege on table {row[0]}.{row[1]} for the database {db_name}" for row in rows
        )

        rows = self.local_db.sql(
            "select schema_name, view_name from collection_postgres_user_views_without_privilege where database_name = $db_name",
            params={"db_name": db_name},
        ).fetchall()
        errors.extend(
            f"user doesn't have SELECT privilege on view {row[0]}.{row[1]} for the database {db_name}" for row in rows
        )

        rows = self.local_db.sql(
            "select namespace_name, rel_name from collection_postgres_user_sequences_without_privilege where database_name = $db_name",
            params={"db_name": db_name},
        ).fetchall()
        errors.extend(
            f"user doesn't have SELECT privilege on sequence {row[0]}.{row[1]} for the database {db_name}"
            for row in rows
        )
        return errors

    def _check_privileges(self, db_name: str, is_pglogical_installed: bool) -> None:
        rule_code = "PRIVILEGES"
        errors: list[str] = []

        if is_pglogical_installed:
            errors = self._check_pglogical_privileges(db_name)

        errors.extend(self.check_user_obj_privileges(db_name))
        all_errors = "\n".join(errors)
        for c in self.rule_config:
            if len(errors) > 0:
                self.save_rule_result(c.db_variant, rule_code, "ERROR", all_errors)
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    f"User has all privileges required for migration for the database {db_name}",
                )

    def _check_wal_level(self) -> None:
        rule_code = "WAL_LEVEL"
        result = self.local_db.sql(
            "select c.setting_value as wal_level from collection_postgres_settings c where c.setting_name='wal_level' and c.setting_value!='logical';"
        ).fetchone()
        wal_level = cast("str", result[0] if result is not None else "unset")
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
                    '`wal_level` is correctly set to "logical".',
                )

    def _check_rds_logical_replication(self) -> None:
        rule_code = "RDS_LOGICAL_REPLICATION"
        is_rds = self._is_rds()
        rds_logical_replication_result = self.local_db.sql(
            "select c.setting_value from collection_postgres_settings c where c.setting_name='rds.logical_replication';"
        ).fetchone()
        rds_logical_replication = (
            rds_logical_replication_result[0] if rds_logical_replication_result is not None else "unset"
        )
        if is_rds:
            for c in self.rule_config:
                if rds_logical_replication != "on":
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        "ERROR",
                        f'`rds.logical_replication` should be set to "on" instead of ({rds_logical_replication})',
                    )
                else:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        "PASS",
                        '`rds.logical_replication` was correctly set to "on"',
                    )

    def _check_max_replication_slots(self) -> None:
        rule_code = "MAX_REPLICATION_SLOTS"
        url_link = "Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
        db_count_result = self.local_db.sql(
            "select count(*) from extended_collection_postgres_all_databases"
        ).fetchone()
        db_count = int(db_count_result[0]) if db_count_result is not None else 0
        total_replication_slots_result = self.local_db.sql(
            "select c.setting_value as max_replication_slots from collection_postgres_settings c where c.setting_name='max_replication_slots';"
        ).fetchone()
        total_replication_slots = (
            int(total_replication_slots_result[0]) if total_replication_slots_result is not None else 0
        )
        used_replication_slots_result = self.local_db.sql(
            "select count(*) from collection_postgres_replication_slots"
        ).fetchone()
        used_replication_slots = (
            int(used_replication_slots_result[0]) if used_replication_slots_result is not None else 0
        )
        required_replication_slots = db_count + used_replication_slots
        for c in self.rule_config:
            max_required_replication_slots = required_replication_slots + c.extra_replication_subscriptions_required
            if total_replication_slots < required_replication_slots:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Insufficient `max_replication_slots`: {total_replication_slots}, should be set to at least {required_replication_slots}. Up to {c.extra_replication_subscriptions_required} additional subscriptions might be required depending on the parallelism level set for migration. {url_link}",
                )
            elif total_replication_slots < max_required_replication_slots:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "WARNING",
                    f"`max_replication_slots` current value: {total_replication_slots}, this might need to be increased to {max_required_replication_slots} depending on the parallelism level set for migration. {url_link}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    f"`max_replication_slots` current value: {total_replication_slots}, this meets or exceeds the maximum required value of {max_required_replication_slots}",
                )

    def _check_max_wal_senders(self) -> None:
        rule_code = "MAX_WAL_SENDERS"
        url_link = "Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
        db_count_result = self.local_db.sql(
            "select count(*) from extended_collection_postgres_all_databases"
        ).fetchone()
        db_count = int(db_count_result[0]) if db_count_result is not None else 0
        wal_senders_result = self.local_db.sql(
            "select c.setting_value as max_wal_senders from collection_postgres_settings c where c.setting_name='max_wal_senders';"
        ).fetchone()
        wal_senders = int(wal_senders_result[0]) if wal_senders_result is not None else 0
        for c in self.rule_config:
            max_required_subscriptions = db_count + c.extra_replication_subscriptions_required
            if wal_senders < db_count:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Insufficient `max_wal_senders`: {wal_senders}, should be set to at least {db_count}. Up to {c.extra_replication_subscriptions_required} additional `wal_senders` might be required depending on the parallelism level set for migration. {url_link}",
                )
            elif wal_senders < max_required_subscriptions:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "WARNING",
                    f"`max_wal_senders` current value: {wal_senders}, this might need to be increased to {max_required_subscriptions} depending on the parallelism level set for migration. {url_link}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    f"`max_wal_senders` current value: {wal_senders}, this meets or exceeds the maximum required value of {max_required_subscriptions}",
                )

    def _check_max_wal_senders_replication_slots(self) -> None:
        rule_code = "WAL_SENDERS_REPLICATION_SLOTS"
        wal_senders_result = self.local_db.sql(
            "select c.setting_value as max_wal_senders from collection_postgres_settings c where c.setting_name='max_wal_senders';"
        ).fetchone()
        wal_senders = int(wal_senders_result[0]) if wal_senders_result is not None else 0
        total_replication_slots_result = self.local_db.sql(
            "select c.setting_value as max_replication_slots from collection_postgres_settings c where c.setting_name='max_replication_slots';"
        ).fetchone()
        total_replication_slots = (
            int(total_replication_slots_result[0]) if total_replication_slots_result is not None else 0
        )
        for c in self.rule_config:
            if wal_senders < total_replication_slots:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Insufficient `max_wal_senders`: {wal_senders}, should be set to at least the same as `max_replication_slots`: {total_replication_slots}.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    f"`max_wal_senders` current value: {wal_senders}, this meets or exceeds the `max_replication_slots` value of {total_replication_slots}",
                )

    def _check_max_worker_processes(self) -> None:
        rule_code = "MAX_WORKER_PROCESSES"
        url_link = "Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
        db_count_result = self.local_db.sql(
            "select count(*) from extended_collection_postgres_all_databases"
        ).fetchone()
        db_count = int(db_count_result[0]) if db_count_result is not None else 0
        max_worker_processes_result = self.local_db.sql(
            "select c.setting_value as max_worker_processes from collection_postgres_settings c where c.setting_name='max_worker_processes';"
        ).fetchone()
        max_worker_processes = int(max_worker_processes_result[0]) if max_worker_processes_result is not None else 0
        for c in self.rule_config:
            max_required_subscriptions = db_count + c.extra_replication_subscriptions_required
            if max_worker_processes < db_count:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "ERROR",
                    f"Insufficient `max_worker_processes`: {max_worker_processes}, should be set to at least {db_count}. Up to {c.extra_replication_subscriptions_required} additional `worker_processes` might be required depending on the parallelism level set for migration. {url_link}",
                )
            elif max_worker_processes < max_required_subscriptions:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "WARNING",
                    f"`max_worker_processes` current value: {max_worker_processes}, this might need to be increased to {max_required_subscriptions} depending on the parallelism level set for migration. {url_link}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    "PASS",
                    f"`max_worker_processes` current value: {max_worker_processes}, this meets or exceeds the maximum required value of {max_required_subscriptions}",
                )

    def _check_extensions(self) -> None:
        rule_code = "EXTENSIONS"
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
                    "All utilized extensions are supported.",
                )

    def _check_fdw(self) -> None:
        rule_code = "FDWS"
        result = self.local_db.sql(
            "select foreign_data_wrapper_name as fdw_name, count(distinct table_schema || table_name) as table_count from collection_postgres_table_details where foreign_data_wrapper_name is not null group by foreign_data_wrapper_name"
        ).fetchall()
        fdws = {row[0] for row in result}
        fdw_table_count = {int(row[1]) for row in result}
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
            "select metric_category, metric_name, metric_value from collection_postgres_calculated_metrics",
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
                "select severity, rule_code, info from readiness_check_summary where migration_target = ?",
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
        result = self.local_db.sql(
            "select case when a.cnt > 0 then true else false end as is_rds from (select count() as cnt from collection_postgres_extensions where extension_owner='rdsadmin' AND is_super_user) a"
        ).fetchone()
        return bool(result[0] > 0) if result is not None else False
