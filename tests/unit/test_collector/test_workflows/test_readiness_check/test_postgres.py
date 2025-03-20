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

from pathlib import Path
from unittest.mock import patch

import pytest
from duckdb import DuckDBPyConnection
from rich import get_console

from dma.collector.workflows.readiness_check._postgres.main import PostgresReadinessCheckExecutor
from dma.collector.workflows.readiness_check.base import ReadinessCheck
from dma.lib.db.base import SourceInfo
from dma.lib.db.local import get_duckdb_connection

pytestmark = pytest.mark.anyio

# Copied from dma/collector/sql/canonical/readiness-check.sql for the tests.
readiness_check_summary = """create or replace table readiness_check_summary(
    migration_target ENUM (
      'CLOUDSQL',
      'ALLOYDB',
      'BMS',
      'SPANNER',
      'BIGQUERY'
    ),
    severity ENUM ('INFO', 'PASS', 'WARNING', 'ACTION REQUIRED', 'ERROR'),
    rule_code varchar,
    info varchar
  );"""


def _dummy_postgres_readiness_executor(
    local_db: DuckDBPyConnection, db_version: str = "dummy"
) -> PostgresReadinessCheckExecutor:
    rc = ReadinessCheck(
        local_db=local_db,
        src_info=SourceInfo("POSTGRES", "test_user", "test_passwd", "dummy_host", 0),
        database="dummy",
        console=get_console(),
        collection_identifier=None,
    )
    rc.db_version = db_version
    return PostgresReadinessCheckExecutor(get_console(), rc)


def _create_readiness_check_summary_table(local_db: DuckDBPyConnection) -> None:
    local_db.execute(readiness_check_summary)


@pytest.mark.parametrize(
    ("collations, expected_severity"),
    [[{"unsupported-locale"}, "ERROR"], [{"c.utf-8"}, "PASS"]],
)
def test_collation(collations, expected_severity):
    with (
        patch(
            "dma.collector.workflows.readiness_check._postgres.main.PostgresReadinessCheckExecutor._get_collation",
            return_value=collations,
        ),
        get_duckdb_connection(Path("tmp/")) as local_db,
    ):
        executor = _dummy_postgres_readiness_executor(local_db)
        _create_readiness_check_summary_table(local_db)
        executor._check_collation()
        rows = local_db.sql(
            "select severity, migration_target, info from readiness_check_summary WHERE rule_code = 'COLLATION'",
        ).fetchall()
        for row in rows:
            assert row[0] == expected_severity


@pytest.mark.parametrize(
    ("rds_logical_replication, expected_severity"),
    [["unset", "ACTION REQUIRED"], ["on", "PASS"]],
)
def test_rds_logical_replication(rds_logical_replication, expected_severity):
    with (
        patch(
            "dma.collector.workflows.readiness_check._postgres.main.PostgresReadinessCheckExecutor._is_rds",
            return_value=True,
        ),
        patch(
            "dma.collector.workflows.readiness_check._postgres.main.PostgresReadinessCheckExecutor._get_rds_logical_replication",
            return_value=rds_logical_replication,
        ),
        get_duckdb_connection(Path("tmp/")) as local_db,
    ):
        executor = _dummy_postgres_readiness_executor(local_db)
        _create_readiness_check_summary_table(local_db)
        executor._check_rds_logical_replication()
        rows = local_db.sql(
            "select severity, migration_target, info from readiness_check_summary WHERE rule_code = 'RDS_LOGICAL_REPLICATION'",
        ).fetchall()
        for row in rows:
            assert row[0] == expected_severity


@pytest.mark.parametrize(
    ("installed_extensions, expected_severity"),
    argvalues=[
        [[["unsupported_ext", "postgres", "postgres"]], "WARNING"],
        [[["unsupported_ext", "alloydbadmin", "postgres"], ["pgAudit", "postgres", "postgres"]], "PASS"],
    ],
)
def test_unsupported_extensions(installed_extensions, expected_severity):
    with (
        patch(
            "dma.collector.workflows.readiness_check._postgres.main.PostgresReadinessCheckExecutor._get_installed_extensions",
            return_value=installed_extensions,
        ),
        get_duckdb_connection(Path("tmp/")) as local_db,
    ):
        executor = _dummy_postgres_readiness_executor(local_db)
        _create_readiness_check_summary_table(local_db)
        executor._check_extensions()
        rows = local_db.sql(
            "select severity, migration_target, info from readiness_check_summary WHERE rule_code = 'UNSUPPORTED_EXTENSIONS_NOT_MIGRATED'",
        ).fetchall()
        for row in rows:
            assert row[0] == expected_severity


@pytest.mark.parametrize(
    ("installed_extensions, expected_severity"),
    argvalues=[
        [[["pg_cron", "postgres", "postgres"]], "WARNING"],
        [[["pgAudit", "postgres", "postgres"]], "PASS"],
    ],
)
def test_unmigrated_extensions(installed_extensions, expected_severity):
    with (
        patch(
            "dma.collector.workflows.readiness_check._postgres.main.PostgresReadinessCheckExecutor._get_installed_extensions",
            return_value=installed_extensions,
        ),
        get_duckdb_connection(Path("tmp/")) as local_db,
    ):
        executor = _dummy_postgres_readiness_executor(local_db)
        _create_readiness_check_summary_table(local_db)
        executor._check_extensions()
        rows = local_db.sql(
            "select severity, migration_target, info from readiness_check_summary WHERE rule_code = 'EXTENSIONS_NOT_MIGRATED'",
        ).fetchall()
        for row in rows:
            assert row[0] == expected_severity


@pytest.mark.parametrize(
    ("database_version, expected_severity"),
    [["10.2", "ERROR"], ["10.7", "PASS"]],
)
def test_rds_db_version(database_version, expected_severity):
    with (
        patch(
            "dma.collector.workflows.readiness_check._postgres.main.PostgresReadinessCheckExecutor._is_rds",
            return_value=True,
        ),
        get_duckdb_connection(Path("tmp/")) as local_db,
    ):
        executor = _dummy_postgres_readiness_executor(local_db, database_version)
        _create_readiness_check_summary_table(local_db)
        executor._check_version()
        rows = local_db.sql(
            "select severity, migration_target, info from readiness_check_summary WHERE rule_code = 'DATABASE_VERSION'",
        ).fetchall()
        for row in rows:
            assert row[0] == expected_severity
