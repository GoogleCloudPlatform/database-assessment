from __future__ import annotations

import asyncio
from pathlib import Path
from typing import TYPE_CHECKING, cast

import pytest
from pytest import FixtureRequest
from pytest_lazyfixture import lazy_fixture
from sqlalchemy import URL, NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

if TYPE_CHECKING:
    from collections import abc


pytestmark = pytest.mark.anyio
here = Path(__file__).parent
root_path = here.parent


@pytest.fixture
def anyio_backend() -> str:
    return "asyncio"


@pytest.fixture(scope="session")
def event_loop() -> "abc.Iterator[asyncio.AbstractEventLoop]":
    """Scoped Event loop.

    Need the event loop scoped to the session so that we can use it to check
    containers are ready in session scoped containers fixture.
    """
    policy = asyncio.get_event_loop_policy()
    loop = policy.new_event_loop()
    try:
        yield loop
    finally:
        loop.close()


@pytest.fixture()
async def asyncmy_engine(docker_ip: str, mysql_service: None) -> AsyncEngine:
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
async def asyncpg_engine(docker_ip: str, postgres_service: None) -> AsyncEngine:
    """Postgresql instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="postgresql+asyncpg",
            username="postgres",
            password="super-secret",  # noqa: S106
            host=docker_ip,
            port=5423,
            database="postgres",
            query={},  # type:ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture()
async def mssql_async_engine(docker_ip: str, mssql_service: None) -> AsyncEngine:
    """MS SQL instance for end-to-end testing."""
    return create_async_engine(
        URL(
            drivername="mssql+aioodbc",
            username="sa",
            password="Super-secret1",  # noqa: S106
            host=docker_ip,
            port=1344,
            database="master",
            query={
                "driver": "ODBC Driver 18 for SQL Server",
                "encrypt": "no",
                "TrustServerCertificate": "yes",
                # NOTE: MARS_Connection is only needed for the concurrent async tests
                # lack of this causes some tests to fail
                # https://github.com/jolt-org/advanced-alchemy/actions/runs/6800623970/job/18493034767?pr=94
                "MARS_Connection": "yes",
            },  # type:ignore[arg-type]
        ),
        poolclass=NullPool,
    )


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
            "asyncmy_engine",
            marks=[
                pytest.mark.asyncmy,
                pytest.mark.integration,
                pytest.mark.xdist_group("mysql"),
            ],
        ),
        pytest.param(
            "asyncpg_engine",
            marks=[
                pytest.mark.asyncpg,
                pytest.mark.integration,
                pytest.mark.xdist_group("postgres"),
            ],
        ),
        pytest.param(
            "mssql_async_engine",
            marks=[
                pytest.mark.mssql_async,
                pytest.mark.integration,
                pytest.mark.xdist_group("mssql"),
            ],
        ),
        pytest.param(
            "oracle18c_async_engine",
            marks=[
                pytest.mark.oracledb_async,
                pytest.mark.integration,
                pytest.mark.xdist_group("oracle18"),
            ],
        ),
        pytest.param(
            "oracle23c_async_engine",
            marks=[
                pytest.mark.oracledb_async,
                pytest.mark.integration,
                pytest.mark.xdist_group("oracle23"),
            ],
        ),
    ],
)
def async_engine(request: FixtureRequest) -> AsyncEngine:
    return cast(AsyncEngine, request.getfixturevalue(request.param))


@pytest.fixture(params=[lazy_fixture("engine"), lazy_fixture("async_engine")], ids=["sync", "async"])
async def any_engine(
    request: FixtureRequest,
) -> AsyncEngine:
    """Return a session for the current session"""
    return cast("AsyncEngine", request.getfixturevalue(request.param))
