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

from pathlib import Path
from textwrap import dedent
from typing import TYPE_CHECKING, Final
from urllib.parse import urlparse

import pytest
from sqlalchemy import text

from dma.cli.main import app
from dma.lib.db.local import get_duckdb_connection

if TYPE_CHECKING:
    from click.testing import CliRunner
    from sqlalchemy import Engine

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
    pytest.mark.xdist_group("postgres"),
]

ACTION_REQUIRED: Final = "ACTION REQUIRED"
ERROR: Final = "ERROR"
WARNING: Final = "WARNING"
PASS: Final = "PASS"


def test_pglogical(
    sync_engine: Engine,
    runner: CliRunner,
) -> None:
    with sync_engine.begin() as conn:
        conn.execute(text(dedent("""create extension if not exists pglogical;""")))
    url = urlparse(str(sync_engine.url.render_as_string(hide_password=False)))
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            f"{url.hostname}",
            "--port",
            f"{url.port!s}",
            "--database",
            f"{url.path.lstrip('/')}",
            "--username",
            f"{url.username}",
            "--password",
            f"{url.password}",
        ],
    )
    assert result.exit_code == 0
    with get_duckdb_connection(Path("tmp/")) as local_db:
        rows = local_db.sql(
            "select severity from readiness_check_summary WHERE rule_code = 'PGLOGICAL_INSTALLED'",
        ).fetchall()
        for row in rows:
            assert row[0] == PASS


def test_privileges_success(
    sync_engine: Engine,
    runner: CliRunner,
) -> None:
    test_user = "testuser"
    test_passwd = "testpasswd"
    with sync_engine.begin() as conn:
        # setup test user.
        conn.execute(text(dedent(f"create user {test_user} WITH PASSWORD '{test_passwd}';")))

        conn.execute(text(dedent("""create extension if not exists pglogical;""")))
        grant_privilege_cmds = [
            "GRANT USAGE on SCHEMA pglogical to testuser",
            "GRANT SELECT on ALL TABLES in SCHEMA pglogical to testuser;"
            "GRANT SELECT on ALL TABLES in SCHEMA public to testuser;",
        ]
        for cmd in grant_privilege_cmds:
            conn.execute(text(cmd))
    url = urlparse(str(sync_engine.url.render_as_string(hide_password=False)))
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            f"{url.hostname}",
            "--port",
            f"{url.port!s}",
            "--database",
            f"{url.path.lstrip('/')}",
            "--username",
            f"{test_user}",
            "--password",
            f"{test_passwd}",
        ],
    )
    # cleanup.
    with sync_engine.begin() as conn:
        conn.execute(text("DROP OWNED BY testuser; DROP USER testuser;"))
    assert result.exit_code == 0
    with get_duckdb_connection(Path("tmp/")) as local_db:
        rows = local_db.sql(
            "select severity, info from readiness_check_summary where rule_code='PRIVILEGES'",
        ).fetchall()
        for row in rows:
            assert row[0] == PASS


def test_privileges_failure(
    sync_engine: Engine,
    runner: CliRunner,
) -> None:
    test_user = "testuser"
    test_passwd = "testpasswd"
    with sync_engine.begin() as conn:
        # setup test user.
        conn.execute(text(dedent(f"create user {test_user} WITH PASSWORD '{test_passwd}';")))
        conn.execute(text(dedent("""create extension if not exists pglogical;""")))
    url = urlparse(str(sync_engine.url.render_as_string(hide_password=False)))
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            f"{url.hostname}",
            "--port",
            f"{url.port!s}",
            "--database",
            f"{url.path.lstrip('/')}",
            "--username",
            f"{test_user}",
            "--password",
            f"{test_passwd}",
        ],
    )

    # Cleanup.
    with sync_engine.begin() as conn:
        conn.execute(text("DROP OWNED BY testuser; DROP USER testuser;"))

    assert result.exit_code == 0
    with get_duckdb_connection(Path("tmp/")) as local_db:
        rows = local_db.sql(
            "select severity, info from readiness_check_summary where rule_code='PRIVILEGES'",
        ).fetchall()
        for row in rows:
            assert row[0] == ACTION_REQUIRED


def test_wal_level(
    sync_engine: Engine,
    runner: CliRunner,
) -> None:
    url = urlparse(str(sync_engine.url.render_as_string(hide_password=False)))
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            f"{url.hostname}",
            "--port",
            f"{url.port!s}",
            "--database",
            f"{url.path.lstrip('/')}",
            "--username",
            f"{url.username}",
            "--password",
            f"{url.password}",
        ],
    )
    assert result.exit_code == 0
    with get_duckdb_connection(Path("tmp/")) as local_db:
        rows = local_db.sql(
            "select severity from readiness_check_summary WHERE rule_code = 'WAL_LEVEL'",
        ).fetchall()
        for row in rows:
            assert row[0] == "PASS"


def test_pg_version(
    sync_engine: Engine,
    runner: CliRunner,
):
    url = urlparse(str(sync_engine.url.render_as_string(hide_password=False)))
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            f"{url.hostname}",
            "--port",
            f"{url.port!s}",
            "--database",
            f"{url.path.lstrip('/')}",
            "--username",
            f"{url.username}",
            "--password",
            f"{url.password}",
        ],
    )
    assert result.exit_code == 0
    with sync_engine.begin() as conn:
        res = conn.execute(text("SHOW server_version_num;"))
        pg_version = res.fetchone()
        pg_major_version = 0
        if pg_version:
            pg_major_version = int(int(pg_version[0]) / 10000)

    with get_duckdb_connection(Path("tmp/")) as local_db:
        rows = local_db.sql(
            "select severity, migration_target, info from readiness_check_summary WHERE rule_code = 'DATABASE_VERSION'",
        ).fetchall()
        for row in rows:
            migration_target = row[1]
            if migration_target == "ALLOYDB" and pg_major_version == 17:
                # AlloyDB doesn't support pg17 yet. Remove this check after AlloyDB supports pg17.
                assert row[0] == ERROR
            else:
                assert row[0] == PASS


def test_pg_source_settings(
    sync_engine: Engine,
    runner: CliRunner,
):
    url = urlparse(str(sync_engine.url.render_as_string(hide_password=False)))
    result = runner.invoke(
        app,
        [
            "readiness-check",
            "--db-type",
            "postgres",
            "--no-prompt",
            "--hostname",
            f"{url.hostname}",
            "--port",
            f"{url.port!s}",
            "--database",
            f"{url.path.lstrip('/')}",
            "--username",
            f"{url.username}",
            "--password",
            f"{url.password}",
        ],
    )
    assert result.exit_code == 0
    with get_duckdb_connection(Path("tmp/")) as local_db:
        rows = local_db.sql(
            "select severity, info from readiness_check_summary WHERE rule_code = 'MAX_REPLICATION_SLOTS'",
        ).fetchall()
        for row in rows:
            assert row[0] == WARNING
            assert (
                row[1]
                == """`max_replication_slots` current value: 10, this might need to be increased to 11 depending on the parallelism level set for migration. Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."""
            )

        rows = local_db.sql(
            "select severity, info from readiness_check_summary WHERE rule_code = 'WAL_SENDERS_REPLICATION_SLOTS'",
        ).fetchall()
        for row in rows:
            assert row[0] == PASS
            assert (
                row[1]
                == """`max_wal_senders` current value: 10, this meets or exceeds the `max_replication_slots` value of 10"""
            )

        rows = local_db.sql(
            "select severity, info from readiness_check_summary WHERE rule_code = 'MAX_WORKER_PROCESSES'",
        ).fetchall()
        for row in rows:
            assert row[0] == WARNING
            assert (
                row[1]
                == "`max_worker_processes` current value: 8, this might need to be increased to 11 depending on the parallelism level set for migration. Refer to https://cloud.google.com/database-migration/docs/postgres/create-migration-job#specify-source-connection-profile-info for more info."
            )
