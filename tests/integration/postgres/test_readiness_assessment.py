# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Integration tests for the CLI."""

from __future__ import annotations

import contextlib
import time
from typing import TYPE_CHECKING, Final

import pytest

from dma.cli.main import app
from dma.lib.db.local import get_duckdb_driver

if TYPE_CHECKING:
    from pathlib import Path

    from click.testing import CliRunner
    from sqlspec.adapters.adbc import AdbcDriver
    from tools.postgres.database import PostgreSQLDatabase

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
    pytest.mark.xdist_group("postgres"),
]

ACTION_REQUIRED: Final = "ACTION REQUIRED"
ERROR: Final = "ERROR"
WARNING: Final = "WARNING"
PASS: Final = "PASS"


def _wait_for_extension(driver: AdbcDriver, extension_name: str, max_retries: int = 5) -> None:
    """Wait for an extension to be visible in a new connection."""
    for _ in range(max_retries):
        result = driver.select(
            "SELECT extname FROM pg_extension WHERE extname = $name",
            name=extension_name,
        )
        if result:
            return
        time.sleep(0.1)
    msg = f"Extension {extension_name} not visible after {max_retries} retries"
    raise AssertionError(msg)


def test_pglogical(
    postgres_collector_db: PostgreSQLDatabase,
    adbc_driver: AdbcDriver,
    runner: CliRunner,
    tmp_path: Path,
) -> None:
    # Install pglogical on current database
    adbc_driver.execute("CREATE EXTENSION IF NOT EXISTS pglogical")
    # Wait for extension to be visible in new connections
    _wait_for_extension(adbc_driver, "pglogical")

    config = postgres_collector_db.config
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            config.postgres_user,
            "--password",
            config.postgres_password,
            "--export",
            str(tmp_path),
        ],
    )
    assert result.exit_code == 0, f"CLI failed: {result.output}"
    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select(
            "SELECT severity, info FROM readiness_check_summary WHERE rule_code = 'PGLOGICAL_INSTALLED'"
        )
        assert len(rows) > 0, "No PGLOGICAL_INSTALLED results found"
        for row in rows:
            # pglogical is installed on test database. Result can be:
            # - PASS: all databases on server have pglogical
            # - ACTION_REQUIRED: some databases (like template DBs) don't have it
            # Both are valid outcomes - we're testing the check runs correctly
            assert row["severity"] in {PASS, ACTION_REQUIRED}, f"Unexpected severity: {row['severity']}"


def test_privileges_success(
    postgres_collector_db: PostgreSQLDatabase,
    adbc_driver: AdbcDriver,
    runner: CliRunner,
    tmp_path: Path,
) -> None:
    test_user = "testuser"
    test_passwd = "testpasswd"
    config = postgres_collector_db.config

    # cleanup from previous runs (if any)
    with contextlib.suppress(Exception):
        adbc_driver.execute_script("DROP OWNED BY testuser; DROP USER IF EXISTS testuser")

    # setup test user
    adbc_driver.execute(f"CREATE USER {test_user} WITH PASSWORD '{test_passwd}'")
    adbc_driver.execute("CREATE EXTENSION IF NOT EXISTS pglogical")

    grant_privilege_cmds = [
        "GRANT USAGE on SCHEMA pglogical to testuser",
        "GRANT SELECT on ALL TABLES in SCHEMA pglogical to testuser",
        "GRANT SELECT on ALL TABLES in SCHEMA public to testuser",
    ]
    for cmd in grant_privilege_cmds:
        adbc_driver.execute(cmd)

    # Wait for extension to be visible
    _wait_for_extension(adbc_driver, "pglogical")

    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            test_user,
            "--password",
            test_passwd,
            "--export",
            str(tmp_path),
        ],
    )
    # cleanup
    adbc_driver.execute_script("DROP OWNED BY testuser; DROP USER testuser")
    assert result.exit_code == 0, f"CLI failed with output: {result.output}"
    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select("SELECT severity, info FROM readiness_check_summary WHERE rule_code='PRIVILEGES'")
        for row in rows:
            assert row["severity"] == PASS, f"Privilege check failed: {row['info']}"


def test_privileges_failure(
    postgres_collector_db: PostgreSQLDatabase,
    adbc_driver: AdbcDriver,
    runner: CliRunner,
    tmp_path: Path,
) -> None:
    test_user = "testuser"
    test_passwd = "testpasswd"
    config = postgres_collector_db.config

    # cleanup from previous runs (if any)
    with contextlib.suppress(Exception):
        adbc_driver.execute_script("DROP OWNED BY testuser; DROP USER IF EXISTS testuser")

    # setup test user
    adbc_driver.execute(f"CREATE USER {test_user} WITH PASSWORD '{test_passwd}'")
    adbc_driver.execute("CREATE EXTENSION IF NOT EXISTS pglogical")

    # Wait for extension to be visible
    _wait_for_extension(adbc_driver, "pglogical")

    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            test_user,
            "--password",
            test_passwd,
            "--export",
            str(tmp_path),
        ],
    )

    # Cleanup
    adbc_driver.execute_script("DROP OWNED BY testuser; DROP USER testuser")

    assert result.exit_code == 0
    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select("SELECT severity, info FROM readiness_check_summary WHERE rule_code='PRIVILEGES'")
        for row in rows:
            assert row["severity"] == ACTION_REQUIRED


def test_wal_level(
    postgres_collector_db: PostgreSQLDatabase,
    runner: CliRunner,
    tmp_path: Path,
) -> None:
    config = postgres_collector_db.config
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            config.postgres_user,
            "--password",
            config.postgres_password,
            "--export",
            str(tmp_path),
        ],
    )
    assert result.exit_code == 0
    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select("SELECT severity FROM readiness_check_summary WHERE rule_code = 'WAL_LEVEL'")
        for row in rows:
            assert row["severity"] == PASS


def test_pg_version(
    postgres_collector_db: PostgreSQLDatabase,
    adbc_driver: AdbcDriver,
    runner: CliRunner,
    tmp_path: Path,
):
    config = postgres_collector_db.config
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            config.postgres_user,
            "--password",
            config.postgres_password,
            "--export",
            str(tmp_path),
        ],
    )
    assert result.exit_code == 0

    # Use pg_settings query instead of SHOW (ADBC wraps queries in COPY which doesn't support SHOW)
    pg_version_num = adbc_driver.select_value("SELECT setting FROM pg_settings WHERE name = 'server_version_num'")
    pg_major_version = int(int(pg_version_num) / 10000)

    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select(
            "SELECT severity, migration_target, info FROM readiness_check_summary WHERE rule_code = 'DATABASE_VERSION'"
        )
        for row in rows:
            migration_target = row["migration_target"]
            if migration_target == "ALLOYDB" and pg_major_version >= 18:
                # AlloyDB max supported version is 17. Update when AlloyDB supports newer versions.
                assert row["severity"] == ERROR
            else:
                assert row["severity"] == PASS


def test_pg_source_settings(
    postgres_collector_db: PostgreSQLDatabase,
    runner: CliRunner,
    tmp_path: Path,
):
    config = postgres_collector_db.config
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            config.postgres_user,
            "--password",
            config.postgres_password,
            "--export",
            str(tmp_path),
        ],
    )
    assert result.exit_code == 0
    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select(
            "SELECT severity, info FROM readiness_check_summary WHERE rule_code = 'MAX_REPLICATION_SLOTS'"
        )
        for row in rows:
            assert row["severity"] == WARNING
            assert (
                row["info"]
                == """`max_replication_slots` current value: 10, this might need to be increased to 11 depending on the parallelism level set for migration. Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."""
            )

        rows = driver.select(
            "SELECT severity, info FROM readiness_check_summary WHERE rule_code = 'WAL_SENDERS_REPLICATION_SLOTS'"
        )
        for row in rows:
            assert row["severity"] == PASS
            assert (
                row["info"]
                == """`max_wal_senders` current value: 10, this meets or exceeds the `max_replication_slots` value of 10"""
            )

        rows = driver.select(
            "SELECT severity, info FROM readiness_check_summary WHERE rule_code = 'MAX_WORKER_PROCESSES'"
        )
        for row in rows:
            assert row["severity"] == WARNING
            assert (
                row["info"]
                == "`max_worker_processes` current value: 8, this might need to be increased to 11 depending on the parallelism level set for migration. Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
            )


def test_tables_without_pk(
    postgres_collector_db: PostgreSQLDatabase,
    adbc_driver: AdbcDriver,
    runner: CliRunner,
    tmp_path: Path,
):
    adbc_driver.execute("CREATE TABLE IF NOT EXISTS test_table (id INTEGER, data text)")
    config = postgres_collector_db.config
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            "localhost",
            "--port",
            str(config.host_port),
            "--database",
            config.postgres_db,
            "--username",
            config.postgres_user,
            "--password",
            config.postgres_password,
            "--export",
            str(tmp_path),
        ],
    )
    assert result.exit_code == 0
    with get_duckdb_driver(working_path=tmp_path, export_path=tmp_path) as driver:
        rows = driver.select("SELECT severity, info FROM readiness_check_summary WHERE rule_code = 'TABLES_WITH_NO_PK'")
        assert len(rows) == 2
        for row in rows:
            assert row["severity"] == WARNING
