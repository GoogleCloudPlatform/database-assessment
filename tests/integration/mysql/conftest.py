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
"""Unit tests for the MySQL."""

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
    pytest.mark.mysql,
    pytest.mark.xdist_group("mysql"),
]


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture(scope="session")
def mysql_sync_engine(
    mysql_docker_ip: str,
    mysql_user: str,
    mysql_password: str,
    mysql_database: str,
    mysql_port: int,
    mysql_service: None,
) -> Generator[Engine, None, None]:
    """MySQL instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="mysql+mysqlconnector",
            username=mysql_user,
            password=mysql_password,
            host=mysql_docker_ip,
            port=mysql_port,
            database=mysql_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def mysql_docker_compose_files() -> list[Path]:
    return [Path(Path(__file__).parent / "docker-compose.yml")]


@pytest.fixture(
    scope="session",
    params=[
        pytest.param(
            "mysql_sync_engine",
            marks=[
                pytest.mark.mysql,
            ],
        ),
    ],
)
def sync_engine(request: FixtureRequest) -> Generator[Engine, None, None]:
    yield cast("Engine", request.getfixturevalue(request.param))
