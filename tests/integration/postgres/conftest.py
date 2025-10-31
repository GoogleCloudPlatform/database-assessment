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

from collections.abc import Callable
from pathlib import Path
from textwrap import dedent
from typing import TYPE_CHECKING, Any

import pytest
from click.testing import CliRunner
from pytest import FixtureRequest
from sqlalchemy import URL, Engine, NullPool, create_engine, text

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


@pytest.fixture(
    scope="session",
    params=[
        "postgres:12-alpine",
        "postgres:13-alpine",
        "postgres:14-alpine",
        "postgres:15-alpine",
        "postgres:16-alpine",
        "postgres:17-alpine",
        "postgres:18-alpine",
    ],
)
def sync_engine(
    database_container: Callable[..., dict[str, Any]], request: FixtureRequest, free_tcp_port_factory: Callable[[], int]
) -> Generator[Engine, None, None]:
    """Postgresql instance for end-to-end testing."""
    from tools.postgres.health import HealthChecker

    def health_check() -> bool:
        """Checks if the postgres container is healthy."""
        checker = HealthChecker()
        health = checker.check_connectivity(host_port=host_port)
        return health.status == "healthy"

    host_port = free_tcp_port_factory()
    db_details = database_container(
        image=request.param,
        name=f"postgres-test-{request.param.replace(':', '-')}",
        host_port=host_port,
        container_port=5432,
        env={
            "POSTGRES_PASSWORD": "super-secret",
            "POSTGRES_USER": "postgres",
            "POSTGRES_DB": "postgres",
        },
        health_check=health_check,
    )

    engine = create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=db_details["env"]["POSTGRES_USER"],
            password=db_details["env"]["POSTGRES_PASSWORD"],
            host="localhost",
            port=db_details["host_port"],
            database=db_details["env"]["POSTGRES_DB"],
            query={},
        ),
        poolclass=NullPool,
    )

    with engine.begin() as conn:
        conn.execute(text(dedent("""create extension if not exists pg_stat_statements;""")))
        driver_connection = conn._dbapi_connection
        assert driver_connection is not None
        cursor = driver_connection.cursor()
        with Path(Path(__file__).parent / "northwind_ddl.sql").open(encoding="utf-8") as f:
            cursor.execute(f.read())
        with Path(Path(__file__).parent / "northwind_data.sql").open(encoding="utf-8") as f:
            cursor.execute(f.read())

    yield engine
