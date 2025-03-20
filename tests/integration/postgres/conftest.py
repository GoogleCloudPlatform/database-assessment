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
"""Unit tests for the Oracle."""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent
from typing import TYPE_CHECKING, cast

import pytest
from click.testing import CliRunner
from pytest import FixtureRequest
from sqlalchemy import URL, Engine, NullPool, create_engine, text

if TYPE_CHECKING:
    from collections.abc import Generator

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
    pytest.mark.xdist_group("postgres"),
]


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture(scope="session")
def postgres17_sync_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres17_port: int,
    postgres17_service: None,
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres17_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def postgres16_sync_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres16_port,
    postgres16_service: None,
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres16_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def postgres15_sync_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres15_port,
    postgres15_service: None,
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres15_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def postgres14_sync_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres14_port,
    postgres14_service: None,
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres14_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def postgres13_sync_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres13_port,
    postgres13_service: None,
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres13_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def postgres12_sync_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres12_port,
    postgres12_service: None,
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres12_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def postgres_docker_compose_files() -> list[Path]:
    return [Path(Path(__file__).parent / "docker-compose.yml")]


@pytest.fixture(
    scope="session",
    params=[
        pytest.param(
            "postgres12_sync_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres13_sync_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres14_sync_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres15_sync_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres16_sync_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres17_sync_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
    ],
)
def sync_engine(request: FixtureRequest) -> Generator[Engine, None, None]:
    yield cast("Engine", request.getfixturevalue(request.param))


@pytest.fixture(scope="session")
def _seed_postgres_database(sync_engine: Engine) -> None:
    with sync_engine.begin() as conn:
        conn.execute(text(dedent("""create extension if not exists pg_stat_statements;""")))
        driver_connection = conn._dbapi_connection
        assert driver_connection is not None
        cursor = driver_connection.cursor()
        with Path(Path(__file__).parent / "northwind_ddl.sql").open(encoding="utf-8") as f:
            cursor.execute(f.read())
        with Path(Path(__file__).parent / "northwind_data.sql").open(encoding="utf-8") as f:
            cursor.execute(f.read())
