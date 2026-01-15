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

from collections import defaultdict
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Any, Final

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

ACTION_REQUIRED: Final = "ACTION REQUIRED"
ERROR: Final = "ERROR"
WARNING: Final = "WARNING"
PASS: Final = "PASS"
PGLOGICAL_INSTALLED: Final = "PGLOGICAL_INSTALLED"
PRIVILEGES: Final = "PRIVILEGES"
PGLOGICAL_NODE_ALREADY_EXISTS: Final = "PGLOGICAL_NODE_ALREADY_EXISTS"
TABLES_WITH_NO_PK: Final = "TABLES_WITH_NO_PK"
UNSUPPORTED_TABLES_WITH_REPLICA_IDENTITY: Final = "UNSUPPORTED_TABLES_WITH_REPLICA_IDENTITY"
REPLICATION_ROLE: Final = "REPLICATION_ROLE"
CLOUDSQL: Final = "CLOUDSQL"
ALLOYDB: Final = "ALLOYDB"
CloudSQL_SUPER_ROLE: Final = "cloudsqladmin"
ALLOYDB_SUPER_ROLE: Final = "alloydbadmin"
NONMIGRATED_EXTENSIONS: Final = {"pg_cron"}


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
        db_variant=ALLOYDB,
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=16,
        supported_collations=ALLOYDB_SUPPORTED_COLLATIONS,
        supported_extensions=ALLOYDB_SUPPORTED_EXTENSIONS,
        supported_fdws=ALLOYDB_SUPPORTED_FDWS,
        extra_replication_subscriptions_required=10,
    ),
    PostgresReadinessCheckTargetConfig(
        db_type="POSTGRES",
        db_variant=CLOUDSQL,
        minimum_supported_major_version=9.4,
        minimum_supported_rds_major_version=9.6,
        maximum_supported_major_version=17,
        supported_collations=CLOUDSQL_SUPPORTED_COLLATIONS,
        supported_extensions=CLOUDSQL_SUPPORTED_EXTENSIONS,
        supported_fdws=CLOUDSQL_SUPPORTED_FDWS,
        extra_replication_subscriptions_required=10,
    ),
]


def init_results_dict(db_check_results: dict, rule_code: str) -> None:
    if not db_check_results.get(rule_code):
        db_check_results[rule_code] = {}
    if not db_check_results[rule_code].get(ACTION_REQUIRED):
        db_check_results[rule_code][ACTION_REQUIRED] = []
    if not db_check_results[rule_code].get(PASS):
        db_check_results[rule_code][PASS] = []
    if not db_check_results[rule_code].get(WARNING):
        db_check_results[rule_code][WARNING] = []


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
        self._check_fdw()

        # Per DB Checks.
        self._check_extensions()
        self._check_replication_role()
        # db_check_results stores the verification results for all DBs.
        for config in self.rule_config:
            db_check_results: dict[str, dict[str, list]] = {}
            for db in sorted(self.get_all_dbs()):
                is_pglogical_installed = self._check_pglogical_installed(db, db_check_results)
                if is_pglogical_installed:
                    privilege_check_passed = self._check_privileges(db, db_check_results)
                    if not privilege_check_passed:
                        continue
                    self._check_if_node_exists(db, db_check_results)
                self._check_tables_without_pk(db, db_check_results)
                self._check_tables_replica_identity(db, db_check_results)
            self._save_results(config.db_variant, db_check_results)

    def _save_results(self, db_variant: PostgresVariants, db_check_results: dict[str, dict[str, list]]) -> None:
        for rule, result in db_check_results.items():
            for severity in [ACTION_REQUIRED, WARNING, PASS]:
                output_str = ""
                if rule == PGLOGICAL_INSTALLED:
                    if severity == ACTION_REQUIRED:
                        output_str = f"`pglogical` extension is not installed on the databases: {','.join(result[ACTION_REQUIRED])}."
                    elif severity == PASS:
                        output_str = f"`pglogical` is installed on the databases: {','.join(result[PASS])}."
                    else:
                        continue

                if rule == PRIVILEGES:
                    if severity == ACTION_REQUIRED:
                        output_str = ";\n\n".join(result[ACTION_REQUIRED])
                    elif severity == PASS:
                        output_str = ";\n".join(result[PASS])
                    else:
                        continue

                if rule == PGLOGICAL_NODE_ALREADY_EXISTS:
                    if severity == ACTION_REQUIRED:
                        output_str = (
                            f"pglogical provider node already exists on databases: {','.join(result[ACTION_REQUIRED])}"
                        )
                    elif severity == PASS:
                        output_str = f"No existing pglogical provider node on the database: {','.join(result[PASS])}"
                    else:
                        continue

                if rule == TABLES_WITH_NO_PK:
                    if severity == WARNING:
                        output_str = f"Some tables have limited support. Tables without primary keys were identified and only INSERT statements will be replicated for these tables: {';'.join(result[WARNING])}"
                    else:
                        continue

                if rule == UNSUPPORTED_TABLES_WITH_REPLICA_IDENTITY:
                    if severity == ACTION_REQUIRED:
                        output_str = f"Source has table(s) with both primary key and replica identity FULL or NOTHING. Please remove replica identity or change it to DEFAULT to migrate: {';'.join(result[ACTION_REQUIRED])}"
                    else:
                        continue

                if len(result[severity]) > 0:
                    self.save_rule_result(
                        db_variant,
                        rule,
                        severity,  # type: ignore
                        output_str,
                    )

    def _get_collation(self) -> set[str]:
        result = self.driver.select("select distinct database_collation from collection_postgres_database_details")
        return {row["database_collation"].lower() for row in result}

    def _check_collation(self) -> None:
        rule_code = "COLLATION"
        collations = self._get_collation()
        for c in self.rule_config:
            supported_collations = {coll.lower() for coll in c.supported_collations}
            unsupported_collations = collations.difference(supported_collations)
            for unsupported_collation in unsupported_collations:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ERROR,
                    f"Unsupported collation: {unsupported_collation} is not supported on this instance",
                )
            if len(unsupported_collations) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    "All utilized collations are supported.",
                )

    def _check_tables_without_pk(self, db_name: str, db_check_results: dict[str, dict[str, list]]) -> None:
        rule_code = TABLES_WITH_NO_PK
        result = self.driver.select(
            "select CONCAT(nspname, '.', relname) as table_name from collection_postgres_tables_with_no_primary_key where database_name = $db_name",
            db_name=db_name,
        )
        tables = ", ".join(row["table_name"] for row in result)
        init_results_dict(db_check_results, rule_code)
        if tables:
            db_check_results[rule_code][WARNING].append(f"In database {db_name}, {tables} don't have primary keys")

    def _check_tables_replica_identity(self, db_name: str, db_check_results: dict[str, dict[str, list]]) -> None:
        rule_code = UNSUPPORTED_TABLES_WITH_REPLICA_IDENTITY
        result = self.driver.select(
            "select CONCAT(nspname, '.', relname) as table_name from collection_postgres_tables_with_primary_key_replica_identity where database_name = $db_name",
            db_name=db_name,
        )
        tables = ", ".join(row["table_name"] for row in result)
        init_results_dict(db_check_results, rule_code)
        if tables:
            db_check_results[rule_code][ACTION_REQUIRED].append(f"{tables} in database {db_name}")

    def _check_version(self) -> None:
        rule_code = "DATABASE_VERSION"
        self.console.print(f"version: {self.db_version}")
        detected_major_version = get_db_major_version(self.db_version)
        detected_minor_version = get_db_minor_version(self.db_version)
        is_rds = self._is_rds()
        self.console.print(
            f"version: {self.db_version}, major version: {detected_major_version}, minor version: {detected_minor_version}"
        )
        for c in self.rule_config:
            if is_rds:
                supported_minor_version = c.rds_minor_version_support_map.get(detected_major_version)
                if supported_minor_version and detected_minor_version < supported_minor_version:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        ERROR,
                        f"Source RDS database server has unsupported minor version: ({detected_minor_version})",
                    )
                else:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        PASS,
                        f"Version {self.db_version} is supported.  Please ensure that you selected a version that meets or exceeds version {detected_major_version!s}.",
                    )
            elif (
                detected_major_version not in c.db_version_map
                or detected_major_version < c.minimum_supported_major_version
                or (c.maximum_supported_major_version and detected_major_version > c.maximum_supported_major_version)
            ):
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ERROR,
                    f"Migration from source database server ({self.db_version}) is not supported",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    f"Version {self.db_version} is supported.  Please ensure that you selected a version that meets or exceeds version {detected_major_version!s}.",
                )

    def _check_pglogical_installed(self, db_name: str, db_check_results: dict[str, dict[str, list]]) -> bool:
        rule_code = PGLOGICAL_INSTALLED
        count = self.driver.select_value(
            "select count(*) from collection_postgres_extensions where extension_name = 'pglogical' and database_name = $db_name",
            db_name=db_name,
        )
        is_installed = count > 0 if count is not None else False
        init_results_dict(db_check_results, rule_code)
        if not is_installed:
            db_check_results[rule_code][ACTION_REQUIRED].append(db_name)
        else:
            db_check_results[rule_code][PASS].append(db_name)
        return is_installed

    def _check_pglogical_schema_usage_privilege(self, db_name: str) -> str | None:
        result = self.driver.select_one_or_none(
            "select has_schema_usage_privilege from collection_postgres_pglogical_schema_usage_privilege where database_name = $db_name",
            db_name=db_name,
        )
        if result is None:
            return "Empty result reading pglogical schema usage privilege for the user"
        if not result["has_schema_usage_privilege"]:
            return "user doesn't have USAGE privilege on schema pglogical"
        return None

    def _check_pglogical_privileges(self, db_name: str) -> list[str]:
        err = self._check_pglogical_schema_usage_privilege(db_name)
        if err is not None:
            return [err]
        result = self.driver.select_one_or_none(
            "select has_tables_select_privilege, has_local_node_select_privilege, has_node_select_privilege, has_node_interface_select_privilege from collection_postgres_pglogical_privileges where database_name = $db_name",
            db_name=db_name,
        )
        errors: list[str] = []
        if result is None:
            errors.append("Empty result reading pglogical privileges for the user")
        else:
            if not result["has_tables_select_privilege"]:
                errors.append("user doesn't have SELECT privilege on table pglogical.tables")
            if not result["has_local_node_select_privilege"]:
                errors.append("user doesn't have SELECT privilege on table pglogical.local_node")
            if not result["has_node_select_privilege"]:
                errors.append("user doesn't have SELECT privilege on table pglogical.node")
            if not result["has_node_interface_select_privilege"]:
                errors.append("user doesn't have SELECT privilege on table pglogical.node_interface")
        return errors

    def _check_if_node_exists(self, db_name: str, db_check_results: dict[str, dict[str, list]]) -> None:
        rule_code = PGLOGICAL_NODE_ALREADY_EXISTS
        count = self.driver.select_value(
            "select count(*) from collection_postgres_pglogical_provider_node where database_name = $db_name",
            db_name=db_name,
        )
        node_exists = count > 0 if count is not None else False
        init_results_dict(db_check_results, rule_code)
        if node_exists:
            db_check_results[rule_code][ACTION_REQUIRED].append(db_name)
        else:
            db_check_results[rule_code][PASS].append(db_name)

    def check_user_obj_privileges(self, db_name: str) -> list[str]:
        errors: list[str] = []
        rows = self.driver.select(
            "select namespace_name from collection_postgres_user_schemas_without_privilege where database_name = $db_name",
            db_name=db_name,
        )
        errors.extend(f"user doesn't have USAGE privilege on schema {row['namespace_name']}" for row in rows)

        rows = self.driver.select(
            "select schema_name, table_name from collection_postgres_user_tables_without_privilege where database_name = $db_name",
            db_name=db_name,
        )
        errors.extend(
            f"user doesn't have SELECT privilege on table {row['schema_name']}.{row['table_name']}" for row in rows
        )

        rows = self.driver.select(
            "select schema_name, view_name from collection_postgres_user_views_without_privilege where database_name = $db_name",
            db_name=db_name,
        )
        errors.extend(
            f"user doesn't have SELECT privilege on view {row['schema_name']}.{row['view_name']}" for row in rows
        )

        rows = self.driver.select(
            "select namespace_name, rel_name from collection_postgres_user_sequences_without_privilege where database_name = $db_name",
            db_name=db_name,
        )
        errors.extend(
            f"user doesn't have SELECT privilege on sequence {row['namespace_name']}.{row['rel_name']}" for row in rows
        )
        return errors

    def _check_replication_role(self) -> None:
        if self._is_rds():
            return
        rule_code = REPLICATION_ROLE
        result = self.driver.select_one_or_none("SELECT rolreplication FROM collection_postgres_replication_role")
        if result is None:
            return
        for c in self.rule_config:
            if result["rolreplication"] == "false":
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    "user does not have rolreplication role.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    "user has rolreplication role.",
                )

    def _check_privileges(self, db_name: str, db_check_results: dict[str, dict[str, list]]) -> bool:
        rule_code = PRIVILEGES
        errors = self._check_pglogical_privileges(db_name)

        errors.extend(self.check_user_obj_privileges(db_name))
        all_errors = "\n".join(errors)
        init_results_dict(db_check_results, rule_code)
        if len(errors) > 0:
            db_check_results[rule_code][ACTION_REQUIRED].append(f"{all_errors} in database {db_name}")
        else:
            db_check_results[rule_code][PASS].append(
                f"User has all privileges required for migration for the database {db_name}"
            )
        return len(errors) == 0

    def _check_wal_level(self) -> None:
        rule_code = "WAL_LEVEL"
        result = self.driver.select_one_or_none(
            "select c.setting_value as wal_level from collection_postgres_settings c where c.setting_name='wal_level' and c.setting_value!='logical'"
        )
        for c in self.rule_config:
            if result is not None:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    f'The `wal_level` settings should be set to "logical" instead of "{result["wal_level"]}".',
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    '`wal_level` is correctly set to "logical".',
                )

    def _get_rds_logical_replication(self) -> str:
        result = self.driver.select_one_or_none(
            "select c.setting_value from collection_postgres_settings c where c.setting_name='rds.logical_replication'"
        )
        return result["setting_value"] if result is not None else "unset"

    def _check_rds_logical_replication(self) -> None:
        rule_code = "RDS_LOGICAL_REPLICATION"
        is_rds = self._is_rds()
        rds_logical_replication = self._get_rds_logical_replication()
        if is_rds:
            for c in self.rule_config:
                if rds_logical_replication != "on":
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        ACTION_REQUIRED,
                        f'`rds.logical_replication` should be set to "on" instead of ({rds_logical_replication})',
                    )
                else:
                    self.save_rule_result(
                        c.db_variant,
                        rule_code,
                        PASS,
                        '`rds.logical_replication` was correctly set to "on"',
                    )

    def _check_max_replication_slots(self) -> None:
        rule_code = "MAX_REPLICATION_SLOTS"
        url_link = "Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
        db_count = self.driver.select_value("select count(*) from extended_collection_postgres_all_databases") or 0
        total_replication_slots = int(
            self.driver.select_value(
                "select c.setting_value from collection_postgres_settings c where c.setting_name='max_replication_slots'"
            )
            or 0
        )
        used_replication_slots = (
            self.driver.select_value("select count(*) from collection_postgres_replication_slots") or 0
        )
        required_replication_slots = db_count + used_replication_slots
        for c in self.rule_config:
            max_required_replication_slots = required_replication_slots + c.extra_replication_subscriptions_required
            if total_replication_slots < required_replication_slots:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    f"Insufficient `max_replication_slots`: {total_replication_slots}, should be set to at least {required_replication_slots}. Up to {c.extra_replication_subscriptions_required} additional subscriptions might be required depending on the parallelism level set for migration. {url_link}",
                )
            elif total_replication_slots < max_required_replication_slots:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    WARNING,
                    f"`max_replication_slots` current value: {total_replication_slots}, this might need to be increased to {max_required_replication_slots} depending on the parallelism level set for migration. {url_link}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    f"`max_replication_slots` current value: {total_replication_slots}, this meets or exceeds the maximum required value of {max_required_replication_slots}",
                )

    def _check_max_wal_senders(self) -> None:
        rule_code = "MAX_WAL_SENDERS"
        url_link = "Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
        db_count = self.driver.select_value("select count(*) from extended_collection_postgres_all_databases") or 0
        wal_senders = int(
            self.driver.select_value(
                "select c.setting_value from collection_postgres_settings c where c.setting_name='max_wal_senders'"
            )
            or 0
        )
        for c in self.rule_config:
            max_required_subscriptions = db_count + c.extra_replication_subscriptions_required
            if wal_senders < db_count:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    f"Insufficient `max_wal_senders`: {wal_senders}, should be set to at least {db_count}. Up to {c.extra_replication_subscriptions_required} additional `wal_senders` might be required depending on the parallelism level set for migration. {url_link}",
                )
            elif wal_senders < max_required_subscriptions:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    WARNING,
                    f"`max_wal_senders` current value: {wal_senders}, this might need to be increased to {max_required_subscriptions} depending on the parallelism level set for migration. {url_link}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    f"`max_wal_senders` current value: {wal_senders}, this meets or exceeds the maximum required value of {max_required_subscriptions}",
                )

    def _check_max_wal_senders_replication_slots(self) -> None:
        rule_code = "WAL_SENDERS_REPLICATION_SLOTS"
        wal_senders = int(
            self.driver.select_value(
                "select c.setting_value from collection_postgres_settings c where c.setting_name='max_wal_senders'"
            )
            or 0
        )
        total_replication_slots = int(
            self.driver.select_value(
                "select c.setting_value from collection_postgres_settings c where c.setting_name='max_replication_slots'"
            )
            or 0
        )
        for c in self.rule_config:
            if wal_senders < total_replication_slots:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    f"Insufficient `max_wal_senders`: {wal_senders}, should be set to at least the same as `max_replication_slots`: {total_replication_slots}.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    f"`max_wal_senders` current value: {wal_senders}, this meets or exceeds the `max_replication_slots` value of {total_replication_slots}",
                )

    def _check_max_worker_processes(self) -> None:
        rule_code = "MAX_WORKER_PROCESSES"
        url_link = "Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
        db_count = self.driver.select_value("select count(*) from extended_collection_postgres_all_databases") or 0
        max_worker_processes = int(
            self.driver.select_value(
                "select c.setting_value from collection_postgres_settings c where c.setting_name='max_worker_processes'"
            )
            or 0
        )
        for c in self.rule_config:
            max_required_subscriptions = db_count + c.extra_replication_subscriptions_required
            if max_worker_processes < db_count:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    f"Insufficient `max_worker_processes`: {max_worker_processes}, should be set to at least {db_count}. Up to {c.extra_replication_subscriptions_required} additional `worker_processes` might be required depending on the parallelism level set for migration. {url_link}",
                )
            elif max_worker_processes < max_required_subscriptions:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    WARNING,
                    f"`max_worker_processes` current value: {max_worker_processes}, this might need to be increased to {max_required_subscriptions} depending on the parallelism level set for migration. {url_link}",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
                    f"`max_worker_processes` current value: {max_worker_processes}, this meets or exceeds the maximum required value of {max_required_subscriptions}",
                )

    def _get_installed_extensions(self) -> list[dict[str, Any]]:
        return self.driver.select(
            "select extension_name, extension_owner, database_name from collection_postgres_extensions"
        )

    @dataclass
    class ExtensionInfo:
        name: str
        owner: str

    def _check_extensions(self) -> None:
        installed_extensions = self._get_installed_extensions()
        installed_db_extensions: defaultdict[str, list[PostgresReadinessCheckExecutor.ExtensionInfo]] = defaultdict(
            list
        )
        for row in installed_extensions:
            ext_name = row["extension_name"]
            ext_owner = row["extension_owner"]
            db_name = row["database_name"]
            exts = installed_db_extensions[db_name]
            exts.append(self.ExtensionInfo(ext_name, ext_owner))

        self._check_unsupported_extensions(installed_db_extensions)
        self._check_extensions_not_migrated(installed_db_extensions)

    def _check_unsupported_extensions(
        self, installed_db_extensions: defaultdict[str, list[PostgresReadinessCheckExecutor.ExtensionInfo]]
    ) -> None:
        unsupported_extensions_rule_code = "UNSUPPORTED_EXTENSIONS_NOT_MIGRATED"
        for c in self.rule_config:
            ext_err = ""
            for db, extensions in installed_db_extensions.items():
                unsupported_extensions = []
                for ext in extensions:
                    if ext.owner in {CloudSQL_SUPER_ROLE, ALLOYDB_SUPER_ROLE}:
                        continue
                    if ext.name not in c.supported_extensions:
                        unsupported_extensions.append(ext.name)
                if len(unsupported_extensions) != 0:
                    ext_err += f"database {db} has unsupported extensions installed and they will not be migrated: {','.join(unsupported_extensions)};\n\n"
            if ext_err == "":
                self.save_rule_result(
                    c.db_variant,
                    unsupported_extensions_rule_code,
                    PASS,
                    "All utilized extensions are supported.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    unsupported_extensions_rule_code,
                    WARNING,
                    ext_err,
                )

    def _check_extensions_not_migrated(
        self, installed_db_extensions: defaultdict[str, list[PostgresReadinessCheckExecutor.ExtensionInfo]]
    ) -> None:
        extensions_not_migrated_rule_code = "EXTENSIONS_NOT_MIGRATED"
        for c in self.rule_config:
            ext_err = ""
            for db, extensions in installed_db_extensions.items():
                extensions_not_migrated = [ext.name for ext in extensions if ext.name in NONMIGRATED_EXTENSIONS]

                if len(extensions_not_migrated) != 0:
                    ext_err += f"database {db} has extensions that will not be migrated: {','.join(extensions_not_migrated)};\n\n"

            if ext_err == "":
                self.save_rule_result(
                    c.db_variant,
                    extensions_not_migrated_rule_code,
                    PASS,
                    "All utilized extensions will be migrated.",
                )
            else:
                self.save_rule_result(
                    c.db_variant,
                    extensions_not_migrated_rule_code,
                    WARNING,
                    ext_err,
                )

    def _check_fdw(self) -> None:
        rule_code = "FDWS"
        result = self.driver.select(
            "select foreign_data_wrapper_name as fdw_name, count(distinct table_schema || table_name) as table_count from collection_postgres_table_details where foreign_data_wrapper_name is not null group by foreign_data_wrapper_name"
        )
        fdw_map = {row["fdw_name"]: int(row["table_count"]) for row in result}
        fdws = set(fdw_map.keys())
        for c in self.rule_config:
            unsupported_fdws = fdws.difference(c.supported_fdws)
            for unsupported_fdw in unsupported_fdws:
                table_count = fdw_map[unsupported_fdw]
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    ACTION_REQUIRED,
                    f'Unsupported FDW: detected {table_count} "{unsupported_fdw}" foreign tables.',
                )
            if len(unsupported_fdws) == 0:
                self.save_rule_result(
                    c.db_variant,
                    rule_code,
                    PASS,
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
        results = self.driver.select(
            "select metric_category, metric_name, metric_value from collection_postgres_calculated_metrics",
        )
        count_table = Table(min_width=80)
        count_table.add_column("Variable Category", justify="right", style="green")
        count_table.add_column("Variable", justify="right", style="green")
        count_table.add_column("Value", justify="right", style="green")
        for row in results:
            count_table.add_row(str(row["metric_category"]), str(row["metric_name"]), str(row["metric_value"]))
        self.console.print(count_table)

    def _print_readiness_check_summary(self) -> None:
        """Print Summary of the Migration Readiness Assessment."""
        db_variants: list[PostgresVariants] = [ALLOYDB, CLOUDSQL]

        def table_for_target(migration_target: PostgresVariants) -> None:
            results = self.driver.select(
                "select severity, rule_code, info from readiness_check_summary where migration_target = $migration_target ORDER BY severity, rule_code",
                migration_target=migration_target,
            )
            count_table = Table(
                min_width=80, title=f"{migration_target} Compatibility", leading=5, title_justify="left"
            )
            count_table.add_column("Severity", justify="right", overflow="fold")
            count_table.add_column("Rule Code", justify="left", overflow="fold")
            count_table.add_column("Info", justify="left", overflow="fold")

            for row in results:
                severity = row["severity"]
                count_table.add_row(
                    f"[bold green]{severity}[/]"
                    if severity == PASS
                    else f"[bold yellow]{severity}[/]"
                    if severity == WARNING
                    else f"[bold red]{severity}[/]",
                    f"[bold]{row['rule_code']}[/]",
                    row["info"],
                )
            self.console.print("\n")
            self.console.print(count_table)
            if migration_target == ALLOYDB:
                self.console.print(
                    "Please refer to the Alloy DB documentation for more details: https://cloud.google.com/database-migration/docs/postgresql-to-alloydb/configure-source-database"
                )
            if migration_target == CLOUDSQL:
                self.console.print(
                    "Please refer to the CloudSQL documentation for more details: https://cloud.google.com/database-migration/docs/postgres/configure-source-database",
                    markup=True,
                )

        for v in db_variants:
            table_for_target(v)

    # helper methods
    def _is_rds(self) -> bool:
        result = self.driver.select_value(
            "select case when a.cnt > 0 then true else false end as is_rds from (select count() as cnt from collection_postgres_extensions where extension_owner='rdsadmin' AND is_super_user) a"
        )
        return bool(result) if result is not None else False
