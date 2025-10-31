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
"""Unit tests for the SQL Server."""

from __future__ import annotations

from pathlib import Path
from typing import TYPE_CHECKING, cast

import pytest
from click.testing import CliRunner
from pytest import FixtureRequest
from sqlalchemy import URL, Engine, NullPool, create_engine

if TYPE_CHECKING:
    from collections.abc import Generator

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.sqlserver,
    pytest.mark.xdist_group("sqlserver"),
]


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture(scope="session")
def sqlserver_sync_engine(
    sqlserver_docker_ip: str,
    sqlserver_user: str,
    sqlserver_password: str,
    sqlserver_database: str,
    sqlserver_port: int,
    sqlserver_service: None,
) -> Generator[Engine, None, None]:
    """SQL Server instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="mssql+pyodbc",
            username=sqlserver_user,
            password=sqlserver_password,
            host=sqlserver_docker_ip,
            port=sqlserver_port,
            database=sqlserver_database,
            query={"driver": "ODBC Driver 17 for SQL Server"},
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def sqlserver_docker_compose_files() -> list[Path]:
    return [Path(Path(__file__).parent / "docker-compose.yml")]


@pytest.fixture(
    scope="session",
    params=[
        pytest.param(
            "sqlserver_sync_engine",
            marks=[
                pytest.mark.sqlserver,
            ],
        ),
    ],
)
def sync_engine(request: FixtureRequest) -> Generator[Engine, None, None]:
    yield cast("Engine", request.getfixturevalue(request.param))
