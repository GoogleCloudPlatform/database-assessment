from __future__ import annotations

from typing import cast

import pytest
from pytest import FixtureRequest
from sqlalchemy import URL, NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

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
            password="super-secret",  # noqa: S106
            host=docker_ip,
            port=3360,
            database="db",
            query={},  # type:ignore[arg-type]
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
            password="super-secret",  # noqa: S106
            host=docker_ip,
            port=3363,
            database="db",
            query={},  # type:ignore[arg-type]
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
            password="super-secret",  # noqa: S106
            host=docker_ip,
            port=3362,
            database="db",
            query={},  # type:ignore[arg-type]
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
                pytest.mark.xdist_group("mysql"),
            ],
        ),
        pytest.param(
            "mysql57_asyncmy_engine",
            marks=[
                pytest.mark.mysql,
                pytest.mark.xdist_group("mysql"),
            ],
        ),
        pytest.param(
            "mysql56_asyncmy_engine",
            marks=[
                pytest.mark.mysql,
                pytest.mark.xdist_group("mysql"),
            ],
        ),
    ],
)
def async_engine(request: FixtureRequest) -> AsyncEngine:
    return cast(AsyncEngine, request.getfixturevalue(request.param))
