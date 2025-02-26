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
from typing import TYPE_CHECKING
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
            assert row[0] == "PASS"


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
