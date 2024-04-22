"""Unit tests for the Oracle."""

from __future__ import annotations

from sys import version_info
from typing import TYPE_CHECKING, cast

import pytest
from pytest import FixtureRequest
from sqlalchemy import URL, NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine

from dma.collector.dependencies import provide_collection_query_manager

if version_info < (3, 10):  # pragma: nocover
    from dma.utils import anext_ as anext  # noqa: A001

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

    from dma.collector.query_managers import CollectionQueryManager

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
]


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
                pytest.mark.xdist_group("postgres12"),
            ],
        ),
        pytest.param(
            "postgres13_async_engine",
            marks=[
                pytest.mark.postgres,
                pytest.mark.xdist_group("postgres13"),
            ],
        ),
        pytest.param(
            "postgres14_async_engine",
            marks=[
                pytest.mark.postgres,
                pytest.mark.xdist_group("postgres14"),
            ],
        ),
        pytest.param(
            "postgres15_async_engine",
            marks=[
                pytest.mark.postgres,
                pytest.mark.xdist_group("postgres15"),
            ],
        ),
        pytest.param(
            "postgres16_async_engine",
            marks=[
                pytest.mark.postgres,
                pytest.mark.xdist_group("postgres16"),
            ],
        ),
    ],
)
def async_engine(request: FixtureRequest) -> AsyncEngine:
    return cast(AsyncEngine, request.getfixturevalue(request.param))


@pytest.fixture(scope="session")
async def collection_queries(async_engine: AsyncEngine) -> AsyncGenerator[CollectionQueryManager, None]:
    async with AsyncSession(async_engine) as db_session:
        yield await anext(provide_collection_query_manager(db_session))
