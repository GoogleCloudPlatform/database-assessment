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
    pytest.mark.mysql,
]


@pytest.fixture()
async def mysql8_asyncmy_engine(docker_ip: str, mysql8_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mysql+asyncmy",
            username="app",
            password="super-secret",
            host=docker_ip,
            port=3360,
            database="db",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def mysql57_asyncmy_engine(docker_ip: str, mysql57_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mysql+asyncmy",
            username="app",
            password="super-secret",
            host=docker_ip,
            port=3363,
            database="db",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def mysql56_asyncmy_engine(docker_ip: str, mysql56_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mysql+asyncmy",
            username="app",
            password="super-secret",
            host=docker_ip,
            port=3362,
            database="db",
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(
    name="async_engine",
    params=[
        pytest.param(
            "mysql8_asyncmy_engine",
            marks=[
                pytest.mark.mysql,
                pytest.mark.xdist_group("mysql8"),
            ],
        ),
        pytest.param(
            "mysql57_asyncmy_engine",
            marks=[
                pytest.mark.mysql,
                pytest.mark.xdist_group("mysql57"),
            ],
        ),
        pytest.param(
            "mysql56_asyncmy_engine",
            marks=[
                pytest.mark.mysql,
                pytest.mark.xdist_group("mysql56"),
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
