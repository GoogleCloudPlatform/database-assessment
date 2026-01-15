# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""Database test fixtures and container management for pytest.

This module provides session-scoped database containers for integration testing,
with support for Docker and Podman, dynamic port allocation, and xdist coordination.

Usage:
    Add "tests.database" to pytest_plugins in conftest.py:

        pytest_plugins = ["tests.database"]

    Then use the database fixtures in your tests:

        def test_something(postgres_collector_db):
            engine = create_engine(
                URL(
                    drivername="postgresql+psycopg",
                    host="localhost",
                    port=postgres_collector_db.config.host_port,
                    ...
                )
            )
"""

from __future__ import annotations

import os
import re
import subprocess
import tempfile
from pathlib import Path
from typing import TYPE_CHECKING

import filelock
import pytest
from tools.lib.container import ContainerRuntime, NoRuntimeAvailableError
from tools.mysql.database import DatabaseConfig as MySQLDatabaseConfig
from tools.mysql.database import MySQLDatabase
from tools.oracle.database import DatabaseConfig as OracleDatabaseConfig
from tools.oracle.database import OracleDatabase
from tools.postgres.database import DatabaseConfig as PostgresDatabaseConfig
from tools.postgres.database import PostgreSQLDatabase
from tools.sqlserver.database import DatabaseConfig as SQLServerDatabaseConfig
from tools.sqlserver.database import SQLServerDatabase

if TYPE_CHECKING:
    from collections.abc import Generator

# =============================================================================
# Version Constants
# =============================================================================

POSTGRES_VERSIONS = [
    "postgres:12",
    "postgres:13",
    "postgres:14",
    "postgres:15",
    "postgres:16",
    "postgres:17",
    "postgres:18",
]

MYSQL_VERSIONS = [
    "mysql:5.7",
    "mysql:8.0",
]

ORACLE_VERSIONS = [
    "gvenzl/oracle-xe:18-slim-faststart",
    "gvenzl/oracle-free:23-slim-faststart",
]

SQLSERVER_VERSIONS = [
    "mcr.microsoft.com/mssql/server:2022-latest",
]


# =============================================================================
# Utility Functions
# =============================================================================


def slugify(value: str) -> str:
    """Convert a string to a URL/container-safe slug.

    Examples:
        slugify("postgres:17") -> "postgres-17"
        slugify("gvenzl/oracle-free:23-slim-faststart") -> "oracle-free-23-slim-faststart"
    """
    # Remove registry prefix if present
    if "/" in value:
        value = value.rsplit("/", maxsplit=1)[-1]
    # Replace colons and other special chars with hyphens
    return re.sub(r"[^a-zA-Z0-9]+", "-", value).strip("-").lower()


def get_xdist_worker_id() -> str:
    """Get the current xdist worker ID.

    Returns:
        Worker ID (e.g., "gw0", "gw1") or "master" if not running under xdist.
    """
    return os.environ.get("PYTEST_XDIST_WORKER", "master")


def is_xdist_master() -> bool:
    """Check if we're running in the xdist master process."""
    return get_xdist_worker_id() == "master"


# =============================================================================
# Session Container Manager
# =============================================================================


class SessionContainerManager:
    """Manages database containers across pytest-xdist workers.

    Uses file locks to coordinate container startup between parallel workers,
    ensuring only one worker starts each container and others wait for it.
    """

    def __init__(self) -> None:
        self.worker_id = get_xdist_worker_id()
        self.runtime = ContainerRuntime()
        self.lock_dir = Path(tempfile.gettempdir()) / "pytest-dma-locks"
        self.lock_dir.mkdir(exist_ok=True, parents=True)
        self._started_containers: list[str] = []

    def get_lock_path(self, name: str) -> Path:
        """Get the lock file path for a container name."""
        return self.lock_dir / f"{name}.lock"

    def ensure_postgres(self, config: PostgresDatabaseConfig) -> PostgreSQLDatabase:
        """Ensure a PostgreSQL container is running.

        Uses file locking to coordinate with other xdist workers.
        """
        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)))
        with lock:
            if self.runtime.container_running(config.container_name):
                # Container already running, just get the port
                if config.host_port is None:
                    db = PostgreSQLDatabase(self.runtime, config)
                    config.host_port = db._get_allocated_port()
            else:
                db = PostgreSQLDatabase(self.runtime, config)
                db.start(pull=False, recreate=False)
                self._started_containers.append(config.container_name)

        return PostgreSQLDatabase(self.runtime, config)

    def ensure_mysql(self, config: MySQLDatabaseConfig) -> MySQLDatabase:
        """Ensure a MySQL container is running."""
        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)))
        with lock:
            if self.runtime.container_running(config.container_name):
                if config.host_port is None:
                    db = MySQLDatabase(self.runtime, config)
                    config.host_port = db._get_allocated_port()
            else:
                db = MySQLDatabase(self.runtime, config)
                db.start(pull=False, recreate=False)
                self._started_containers.append(config.container_name)

        return MySQLDatabase(self.runtime, config)

    def ensure_oracle(self, config: OracleDatabaseConfig) -> OracleDatabase:
        """Ensure an Oracle container is running."""
        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)))
        with lock:
            if self.runtime.container_running(config.container_name):
                if config.host_port is None:
                    db = OracleDatabase(self.runtime, config)
                    config.host_port = db._get_allocated_port()
            else:
                db = OracleDatabase(self.runtime, config)
                db.start(pull=False, recreate=False)
                self._started_containers.append(config.container_name)

        return OracleDatabase(self.runtime, config)

    def ensure_sqlserver(self, config: SQLServerDatabaseConfig) -> SQLServerDatabase:
        """Ensure a SQL Server container is running."""
        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)))
        with lock:
            if self.runtime.container_running(config.container_name):
                if config.host_port is None:
                    db = SQLServerDatabase(self.runtime, config)
                    config.host_port = db._get_allocated_port()
            else:
                db = SQLServerDatabase(self.runtime, config)
                db.start(pull=False, recreate=False)
                self._started_containers.append(config.container_name)

        return SQLServerDatabase(self.runtime, config)


# =============================================================================
# Pytest Fixtures
# =============================================================================


@pytest.fixture(scope="session")
def container_manager() -> Generator[SessionContainerManager, None, None]:
    """Session-scoped container manager for database containers."""
    manager = SessionContainerManager()

    if not manager.runtime.is_available():
        pytest.skip("No container runtime (Docker/Podman) available")

    yield manager


@pytest.fixture(scope="session")
def postgres_docker_ip() -> str:
    """Return the Docker host IP address for PostgreSQL connections."""
    return "localhost"


@pytest.fixture(scope="session")
def postgres_user() -> str:
    """Return the PostgreSQL username."""
    return "postgres"


@pytest.fixture(scope="session")
def postgres_password() -> str:
    """Return the PostgreSQL password."""
    return "super-secret"


@pytest.fixture(scope="session")
def postgres_database() -> str:
    """Return the PostgreSQL database name."""
    return "postgres"


@pytest.fixture(scope="session", params=POSTGRES_VERSIONS, ids=slugify)
def postgres_collector_db(
    request: pytest.FixtureRequest,
    container_manager: SessionContainerManager,
) -> Generator[PostgreSQLDatabase, None, None]:
    """Session-scoped PostgreSQL database container.

    Parameterized to test against multiple PostgreSQL versions.
    Uses dynamic port allocation to avoid conflicts.
    """
    image = request.param
    version_tag = slugify(image)

    # Check if we need to build a custom image (for pglogical support)
    postgres_integration_dir = Path(__file__).parent / "integration" / "postgres"
    dockerfile_path = postgres_integration_dir / "Dockerfile"

    if dockerfile_path.exists():
        # Extract major version from image tag
        version_match = re.search(r":(\d+)", image)
        if version_match:
            pg_version = version_match.group(1)
            pg_major = int(pg_version)
            custom_image = f"dma-test-postgres-pglogical:{pg_version}"

            # PG 18+ changed the data directory structure
            # See: https://github.com/docker-library/postgres/pull/1259
            data_mount_path = "/var/lib/postgresql" if pg_major >= 18 else "/var/lib/postgresql/data"

            config = PostgresDatabaseConfig(
                image=custom_image,
                container_name=f"dma-test-pg-collector-{version_tag}",
                data_volume_name=f"dma-test-pg-data-{version_tag}",
                host_port=None,
                build_context=postgres_integration_dir,
                dockerfile=dockerfile_path,
                build_args={"PG_VERSION": pg_version},
                data_mount_path=data_mount_path,
                extra_command=[
                    "-c",
                    "wal_level=logical",
                    "-c",
                    "shared_preload_libraries=pg_stat_statements,pglogical",
                ],
            )
        else:
            config = PostgresDatabaseConfig(
                image=image,
                container_name=f"dma-test-pg-collector-{version_tag}",
                data_volume_name=f"dma-test-pg-data-{version_tag}",
                host_port=None,
            )
    else:
        config = PostgresDatabaseConfig(
            image=image,
            container_name=f"dma-test-pg-collector-{version_tag}",
            data_volume_name=f"dma-test-pg-data-{version_tag}",
            host_port=None,
        )

    db = container_manager.ensure_postgres(config)
    yield db


# Version-specific PostgreSQL fixtures for backwards compatibility
@pytest.fixture(scope="session")
def postgres12_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 12."""
    if "postgres:12" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 12")
    return postgres_collector_db.config.host_port or 5432


@pytest.fixture(scope="session")
def postgres13_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 13."""
    if "postgres:13" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 13")
    return postgres_collector_db.config.host_port or 5432


@pytest.fixture(scope="session")
def postgres14_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 14."""
    if "postgres:14" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 14")
    return postgres_collector_db.config.host_port or 5432


@pytest.fixture(scope="session")
def postgres15_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 15."""
    if "postgres:15" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 15")
    return postgres_collector_db.config.host_port or 5432


@pytest.fixture(scope="session")
def postgres16_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 16."""
    if "postgres:16" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 16")
    return postgres_collector_db.config.host_port or 5432


@pytest.fixture(scope="session")
def postgres17_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 17."""
    if "postgres:17" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 17")
    return postgres_collector_db.config.host_port or 5432


@pytest.fixture(scope="session")
def postgres18_port(postgres_collector_db: PostgreSQLDatabase, request: pytest.FixtureRequest) -> int:
    """Port for PostgreSQL 18."""
    if "postgres:18" not in str(request.node.callspec.params.get("postgres_collector_db", "")):
        pytest.skip("Not testing PostgreSQL 18")
    return postgres_collector_db.config.host_port or 5432


# Version-specific service fixtures (no-op, for backwards compatibility)
@pytest.fixture(scope="session")
def postgres12_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 12 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session")
def postgres13_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 13 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session")
def postgres14_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 14 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session")
def postgres15_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 15 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session")
def postgres16_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 16 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session")
def postgres17_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 17 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session")
def postgres18_service(postgres_collector_db: PostgreSQLDatabase) -> None:
    """Ensure PostgreSQL 18 is running (backwards compatibility)."""
    return


@pytest.fixture(scope="session", params=MYSQL_VERSIONS, ids=slugify)
def mysql_collector_db(
    request: pytest.FixtureRequest,
    container_manager: SessionContainerManager,
) -> Generator[MySQLDatabase, None, None]:
    """Session-scoped MySQL database container."""
    image = request.param
    version_tag = slugify(image)

    config = MySQLDatabaseConfig(
        image=image,
        container_name=f"dma-test-mysql-collector-{version_tag}",
        data_volume_name=f"dma-test-mysql-data-{version_tag}",
        host_port=None,
    )

    db = container_manager.ensure_mysql(config)
    yield db


@pytest.fixture(scope="session", params=ORACLE_VERSIONS, ids=slugify)
def oracle_collector_db(
    request: pytest.FixtureRequest,
    container_manager: SessionContainerManager,
) -> Generator[OracleDatabase, None, None]:
    """Session-scoped Oracle database container."""
    image = request.param
    version_tag = slugify(image)

    config = OracleDatabaseConfig(
        image=image,
        container_name=f"dma-test-oracle-collector-{version_tag}",
        data_volume_name=f"dma-test-oracle-data-{version_tag}",
        host_port=None,
    )

    db = container_manager.ensure_oracle(config)
    yield db


@pytest.fixture(scope="session", params=SQLSERVER_VERSIONS, ids=slugify)
def sqlserver_collector_db(
    request: pytest.FixtureRequest,
    container_manager: SessionContainerManager,
) -> Generator[SQLServerDatabase, None, None]:
    """Session-scoped SQL Server database container."""
    image = request.param
    version_tag = slugify(image)

    config = SQLServerDatabaseConfig(
        image=image,
        container_name=f"dma-test-mssql-collector-{version_tag}",
        data_volume_name=f"dma-test-mssql-data-{version_tag}",
        host_port=None,
    )

    db = container_manager.ensure_sqlserver(config)
    yield db


# =============================================================================
# Pytest Hooks
# =============================================================================


def pytest_sessionfinish(session: pytest.Session, exitstatus: int) -> None:
    """Clean up test containers at the end of the session.

    Only the master xdist process performs cleanup to avoid race conditions.
    """
    # Only master/main process cleans up
    if not is_xdist_master():
        return

    try:
        runtime = ContainerRuntime()
    except NoRuntimeAvailableError:
        return

    if not runtime.is_available():
        return

    cmd = runtime.get_runtime_command()

    # Remove test containers
    containers = runtime.list_containers(include_all=True)
    test_containers = [c for c in containers if c.startswith("dma-test-")]
    if test_containers:
        subprocess.run([cmd, "rm", "-f", *test_containers], capture_output=True, check=False)

    # Remove volumes unless DMA_TEST_KEEP_VOLUMES is set
    keep_volumes = os.environ.get("DMA_TEST_KEEP_VOLUMES", "").lower() in {"1", "true", "yes"}
    if not keep_volumes:
        volumes = runtime.list_volumes()
        test_volumes = [v for v in volumes if v.startswith("dma-test-")]
        if test_volumes:
            subprocess.run([cmd, "volume", "rm", "-f", *test_volumes], capture_output=True, check=False)


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Add xdist_group markers based on database type and version.

    This ensures tests for the same database version run on the same worker
    AND are serialized (not run in parallel), preventing test interference
    when tests modify shared database state.
    """
    for item in items:
        # Check for database fixtures in the test
        if not hasattr(item, "fixturenames"):
            continue

        # Get version-specific group name from parameterization
        group_suffix = ""
        if hasattr(item, "callspec") and hasattr(item.callspec, "params"):
            for param_name, param_value in item.callspec.params.items():
                if "collector_db" in param_name and param_value:
                    # Extract version from parameter value (e.g., "postgres:12" -> "12")
                    group_suffix = f"-{slugify(str(param_value))}"
                    break

        if "postgres_collector_db" in item.fixturenames:
            item.add_marker(pytest.mark.xdist_group(f"postgres{group_suffix}"))
        elif "mysql_collector_db" in item.fixturenames:
            item.add_marker(pytest.mark.xdist_group(f"mysql{group_suffix}"))
        elif "oracle_collector_db" in item.fixturenames:
            item.add_marker(pytest.mark.xdist_group(f"oracle{group_suffix}"))
        elif "sqlserver_collector_db" in item.fixturenames:
            item.add_marker(pytest.mark.xdist_group(f"sqlserver{group_suffix}"))
