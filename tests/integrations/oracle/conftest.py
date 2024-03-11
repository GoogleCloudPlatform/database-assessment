"""Unit tests for the Oracle."""

from __future__ import annotations

import platform
from sys import version_info
from typing import TYPE_CHECKING, cast

import pytest
from pytest import FixtureRequest
from sqlalchemy import NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, create_async_engine

from dma.collector.queries import provides_collection_queries

if version_info < (3, 10):  # pragma: nocover
    from dma.utils import anext_ as anext  # noqa: A001
if TYPE_CHECKING:
    from collections.abc import AsyncGenerator

    from dma.collector.query_manager import CollectionQueryManager

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.skipif(platform.uname()[4] != "x86_64", reason="oracle not available on this platform"),
    pytest.mark.oracle,
]


@pytest.fixture()
async def oracle18c_async_engine(docker_ip: str, oracle18c_service: None) -> AsyncEngine:
    """Oracle 18c instance for end-to-end testing.

    Args:
        docker_ip: IP address for TCP connection to Docker containers.
        oracle18c_service: ...

    Returns:
        Async SQLAlchemy engine instance.
    """
    return create_async_engine(
        "oracle+oracledb://:@",
        thick_mode=False,
        connect_args={
            "user": "app",
            "password": "super-secret",
            "host": docker_ip,
            "port": 1512,
            "service_name": "xepdb1",
        },
        poolclass=NullPool,
    )


@pytest.fixture()
async def oracle23c_async_engine(docker_ip: str, oracle23c_service: None) -> AsyncEngine:
    """Oracle 23c instance for end-to-end testing.

    Args:
        docker_ip: IP address for TCP connection to Docker containers.
        oracle23c_service: ...

    Returns:
        Async SQLAlchemy engine instance.
    """
    return create_async_engine(
        "oracle+oracledb://:@",
        thick_mode=False,
        connect_args={
            "user": "app",
            "password": "super-secret",
            "host": docker_ip,
            "port": 1513,
            "service_name": "FREEPDB1",
        },
        poolclass=NullPool,
    )


@pytest.fixture(
    name="async_engine",
    params=[
        pytest.param(
            "oracle18c_async_engine",
            marks=[
                pytest.mark.oracle,
                pytest.mark.xdist_group("oracle18c"),
            ],
        ),
        pytest.param(
            "oracle23c_async_engine",
            marks=[
                pytest.mark.oracle,
                pytest.mark.xdist_group("oracle23c"),
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
