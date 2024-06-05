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
from __future__ import annotations

from typing import cast

import pytest
from pytest import FixtureRequest
from sqlalchemy import URL, NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.mysql,
    pytest.mark.xdist_group("mysql"),
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
            marks=[pytest.mark.mysql],
        ),
        pytest.param(
            "mysql57_asyncmy_engine",
            marks=[pytest.mark.mysql],
        ),
        pytest.param(
            "mysql56_asyncmy_engine",
            marks=[pytest.mark.mysql],
        ),
    ],
)
def async_engine(request: FixtureRequest) -> AsyncEngine:
    return cast(AsyncEngine, request.getfixturevalue(request.param))
