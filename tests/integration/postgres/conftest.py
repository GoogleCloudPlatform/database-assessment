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
from typing import TYPE_CHECKING

import pytest
from click.testing import CliRunner
from sqlspec.adapters.adbc import AdbcConfig

if TYPE_CHECKING:
    from collections.abc import Generator

    from sqlspec.adapters.adbc import AdbcDriver
    from tools.postgres.database import PostgreSQLDatabase

pytestmark = [
    pytest.mark.anyio,
    pytest.mark.postgres,
]


@pytest.fixture
def runner() -> CliRunner:
    return CliRunner()


@pytest.fixture(scope="session")
def adbc_config(postgres_collector_db: PostgreSQLDatabase) -> AdbcConfig:
    """ADBC configuration for the current PostgreSQL version.

    This fixture is parameterized through postgres_collector_db, which tests
    against all supported PostgreSQL versions (12-18).

    Uses autocommit to ensure changes are visible to CLI's separate connection.
    """
    config = postgres_collector_db.config
    uri = f"postgresql://{config.postgres_user}:{config.postgres_password}@localhost:{config.host_port}/{config.postgres_db}"
    return AdbcConfig(connection_config={"uri": uri, "autocommit": True})


@pytest.fixture(scope="session")
def adbc_driver(adbc_config: AdbcConfig) -> Generator[AdbcDriver, None, None]:
    """ADBC driver for the current PostgreSQL version."""
    with adbc_config.provide_session() as driver:
        yield driver


@pytest.fixture(scope="session")
def _seed_postgres_database(adbc_driver: AdbcDriver) -> None:
    """Seed the test database with northwind data."""
    # Create pg_stat_statements extension
    adbc_driver.execute("CREATE EXTENSION IF NOT EXISTS pg_stat_statements")

    # Load northwind DDL and data
    ddl_path = Path(__file__).parent / "northwind_ddl.sql"
    data_path = Path(__file__).parent / "northwind_data.sql"

    adbc_driver.execute(ddl_path.read_text(encoding="utf-8"))
    adbc_driver.execute(data_path.read_text(encoding="utf-8"))
