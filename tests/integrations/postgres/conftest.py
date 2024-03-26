"""Unit tests for the Oracle."""

from __future__ import annotations

from sys import version_info
from typing import TYPE_CHECKING, cast

import pytest
from pytest import FixtureRequest
from sqlalchemy import URL, NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine

from dma.collector.queries import provides_collection_queries

if version_info < (3, 10):  # pragma: nocover
    from dma.utils import anext_ as anext  # noqa: A001

if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

    from dma.collector.query_manager import CollectionQueryManager

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
]


@pytest.fixture()
async def postgres16_async_engine(docker_ip: str, postgres16_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username="postgres",
            password="super-secret",
            host=docker_ip,
            port=5427,
            database="postgres",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def postgres15_async_engine(docker_ip: str, postgres15_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username="postgres",
            password="super-secret",
            host=docker_ip,
            port=5426,
            database="postgres",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def postgres14_async_engine(docker_ip: str, postgres14_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username="postgres",
            password="super-secret",
            host=docker_ip,
            port=5425,
            database="postgres",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def postgres13_async_engine(docker_ip: str, postgres13_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username="postgres",
            password="super-secret",
            host=docker_ip,
            port=5424,
            database="postgres",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def postgres12_async_engine(docker_ip: str, postgres12_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username="postgres",
            password="super-secret",
            host=docker_ip,
            port=5423,
            database="postgres",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(
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


@pytest.fixture()
async def collection_queries(async_engine: AsyncEngine) -> AsyncGenerator[CollectionQueryManager, None]:
    async with AsyncSession(async_engine) as db_session:
        yield await anext(provides_collection_queries(db_session))
