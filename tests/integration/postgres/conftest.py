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

from textwrap import dedent
from typing import TYPE_CHECKING, cast

import pytest
from click.testing import CliRunner
from pytest import FixtureRequest
from sqlalchemy import URL, NullPool, text
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

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
async def postgres17_async_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres17_port: int,
    postgres17_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
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
async def postgres16_async_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres16_port,
    postgres16_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
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
async def postgres15_async_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres15_port,
    postgres15_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
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
async def postgres14_async_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres14_port,
    postgres14_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
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
async def postgres13_async_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres13_port,
    postgres13_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
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
async def postgres12_async_engine(
    postgres_docker_ip: str,
    postgres_user: str,
    postgres_password: str,
    postgres_database: str,
    postgres12_port,
    postgres12_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username=postgres_user,
            password=postgres_password,
            host=postgres_docker_ip,
            port=postgres12_port,
            database=postgres_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(
    scope="session",
    params=[
        pytest.param(
            "postgres12_async_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres13_async_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres14_async_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres15_async_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres16_async_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
        pytest.param(
            "postgres17_async_engine",
            marks=[
                pytest.mark.postgres,
            ],
        ),
    ],
)
def async_engine(request: FixtureRequest) -> Generator[AsyncEngine, None, None]:
    yield cast("AsyncEngine", request.getfixturevalue(request.param))


@pytest.fixture(scope="session")
async def _seed_postgres_database(async_engine: AsyncEngine) -> None:
    async with async_engine.begin() as conn:
        await conn.execute(text(dedent("""create extension if not exists pg_stat_statements;""")))
