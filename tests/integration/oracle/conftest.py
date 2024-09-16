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

import platform
from typing import cast

import pytest
from pytest import FixtureRequest
from sqlalchemy import NullPool
from sqlalchemy.ext.asyncio import AsyncEngine, create_async_engine

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.skipif(platform.uname()[4] != "x86_64", reason="oracle not available on this platform"),
    pytest.mark.oracle,
    pytest.mark.xdist_group("oracle"),
]


@pytest.fixture(scope="session")
async def oracle18c_async_engine(
    oracle_docker_ip: str,
    oracle_user: str,
    oracle_password: str,
    oracle18c_port: int,
    oracle18c_service_name: str,
    oracle18c_service: None,
) -> AsyncEngine:
    """Oracle 18c instance for end-to-end testing.


    Returns:
        Async SQLAlchemy engine instance.
    """
    return create_async_engine(
        "oracle+oracledb://:@",
        thick_mode=False,
        connect_args={
            "user": oracle_user,
            "password": oracle_password,
            "host": oracle_docker_ip,
            "port": oracle18c_port,
            "service_name": oracle18c_service_name,
        },
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
async def oracle23ai_async_engine(
    oracle_docker_ip: str,
    oracle_user: str,
    oracle_password: str,
    oracle23ai_port: int,
    oracle23ai_service_name: str,
    oracle23ai_service: None,
) -> AsyncEngine:
    """Oracle 23c instance for end-to-end testing.



    Returns:
        Async SQLAlchemy engine instance.
    """
    return create_async_engine(
        "oracle+oracledb://:@",
        thick_mode=False,
        connect_args={
            "user": oracle_user,
            "password": oracle_password,
            "host": oracle_docker_ip,
            "port": oracle23ai_port,
            "service_name": oracle23ai_service_name,
        },
        poolclass=NullPool,
    )


@pytest.fixture(
    scope="session",
    name="async_engine",
    params=[
        pytest.param(
            "oracle18c_async_engine",
            marks=[pytest.mark.oracle],
        ),
        pytest.param(
            "oracle23ai_async_engine",
            marks=[pytest.mark.oracle],
        ),
    ],
)
def async_engine(request: FixtureRequest) -> AsyncEngine:
    return cast(AsyncEngine, request.getfixturevalue(request.param))
