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

from typing import TYPE_CHECKING
from urllib.parse import urlparse

import pytest

from dma.cli.main import app

if TYPE_CHECKING:
    from click.testing import CliRunner
    from sqlalchemy import Engine

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
    pytest.mark.xdist_group("postgres"),
]


def test_cli_postgres(
    sync_engine: Engine,
    _seed_postgres_database: None,
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
