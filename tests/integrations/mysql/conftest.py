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
    pytest.mark.mysql,
]


@pytest.fixture(scope="session")
async def mysql8_asyncmy_engine(
    mysql_docker_ip: str,
    mysql_user: str,
    mysql_password: str,
    mysql_database: str,
    mysql8_port: int,
    mysql8_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mysql+asyncmy",
            username=mysql_user,
            password=mysql_password,
            host=mysql_docker_ip,
            port=mysql8_port,
            database=mysql_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
async def mysql57_asyncmy_engine(
    mysql_docker_ip: str,
    mysql_user: str,
    mysql_password: str,
    mysql_database: str,
    mysql57_port: int,
    mysql57_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mysql+asyncmy",
            username=mysql_user,
            password=mysql_password,
            host=mysql_docker_ip,
            port=mysql57_port,
            database=mysql_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
async def mysql56_asyncmy_engine(
    mysql_docker_ip: str,
    mysql_user: str,
    mysql_password: str,
    mysql_database: str,
    mysql56_port: int,
    mysql56_service: None,
) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mysql+asyncmy",
            username=mysql_user,
            password=mysql_password,
            host=mysql_docker_ip,
            port=mysql56_port,
            database=mysql_database,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(
    scope="session",
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


@pytest.fixture(scope="session")
async def collection_queries(async_engine: AsyncEngine) -> AsyncGenerator[CollectionQueryManager, None]:
    async with AsyncSession(async_engine) as db_session:
        yield await anext(provide_collection_query_manager(db_session))
