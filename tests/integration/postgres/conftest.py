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
"""PostgreSQL integration test fixtures."""

from __future__ import annotations

from pathlib import Path
from textwrap import dedent
from typing import TYPE_CHECKING

import pytest
from click.testing import CliRunner
from sqlalchemy import URL, Engine, NullPool, create_engine, text

if TYPE_CHECKING:
    from collections.abc import Generator

    from tools.postgres.database import PostgreSQLDatabase

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
    pytest.mark.xdist_group("postgres"),
]


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture(scope="session")
def sync_engine(postgres_collector_db: PostgreSQLDatabase) -> Generator[Engine, None, None]:
    """SQLAlchemy engine for the current PostgreSQL version.

    This fixture is parameterized through postgres_collector_db, which tests
    against all supported PostgreSQL versions (12-17).
    """
    config = postgres_collector_db.config
    yield create_engine(
        URL(
            drivername="postgresql+psycopg",
            username=config.postgres_user,
            password=config.postgres_password,
            host="localhost",
            port=config.host_port,
            database=config.postgres_db,
            query={},  # type: ignore[arg-type]
        ),
        poolclass=NullPool,
    )


@pytest.fixture(scope="session")
def _seed_postgres_database(sync_engine: Engine) -> None:
    with sync_engine.begin() as conn:
        conn.execute(text(dedent("""create extension if not exists pg_stat_statements;""")))
        driver_connection = conn._dbapi_connection
        assert driver_connection is not None
        cursor = driver_connection.cursor()
        cursor.execute(Path(Path(__file__).parent / "northwind_ddl.sql").read_text(encoding="utf-8"))
        cursor.execute(Path(Path(__file__).parent / "northwind_data.sql").read_text(encoding="utf-8"))
