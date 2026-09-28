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

import json
import os
import re
import subprocess
import tempfile
import time
from pathlib import Path
from typing import TYPE_CHECKING, Any

import filelock
import pytest
from tools.lib.container import ContainerRuntime, NoRuntimeAvailableError
from tools.mysql.database import ContainerStartError as MySQLContainerStartError
from tools.mysql.database import DatabaseConfig as MySQLDatabaseConfig
from tools.mysql.database import MySQLDatabase
from tools.oracle.database import ContainerStartError as OracleContainerStartError
from tools.oracle.database import DatabaseConfig as OracleDatabaseConfig
from tools.oracle.database import OracleDatabase
from tools.postgres.database import ContainerStartError as PostgresContainerStartError
from tools.postgres.database import DatabaseConfig as PostgresDatabaseConfig
from tools.postgres.database import PostgreSQLDatabase
from tools.sqlserver.database import ContainerStartError as SQLServerContainerStartError
from tools.sqlserver.database import DatabaseConfig as SQLServerDatabaseConfig
from tools.sqlserver.database import SQLServerDatabase

if TYPE_CHECKING:
    from collections.abc import Generator

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


def slugify(value: str) -> str:
    """Convert a string to a URL/container-safe slug.

    Strips any registry prefix before replacing non-alphanumeric characters
    with hyphens.

    Examples:
        slugify("postgres:17") -> "postgres-17"
        slugify("gvenzl/oracle-free:23-slim-faststart") -> "oracle-free-23-slim-faststart"
    """
    if "/" in value:
        value = value.rsplit("/", maxsplit=1)[-1]
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


class SessionRegistry:
    """Tracks started containers across xdist workers in a shared JSON file."""

    def __init__(self, run_uid: str | None = None) -> None:
        uid = run_uid or os.environ.get("DMA_TEST_RUN_UID", "default")
        self.base_dir = Path(tempfile.gettempdir())
        self.registry_file = self.base_dir / f"pytest-dma-session-{uid}.json"
        self.lock_file = self.base_dir / f"pytest-dma-session-{uid}.lock"

    def _read_data(self) -> dict[str, Any]:
        if not self.registry_file.exists():
            return {"containers_started": []}
        try:
            with self.registry_file.open("r", encoding="utf-8") as f:
                data: dict[str, Any] = json.load(f)
                return data
        except (OSError, json.JSONDecodeError):
            return {"containers_started": []}

    def _write_data(self, data: dict[str, Any]) -> None:
        try:
            with self.registry_file.open("w", encoding="utf-8") as f:
                json.dump(data, f)
        except OSError:
            pass

    def record_container_started(self, container_name: str) -> None:
        """Record that a container was started during this test session."""
        with filelock.FileLock(str(self.lock_file), timeout=30):
            data = self._read_data()
            started: list[str] = data.setdefault("containers_started", [])
            if container_name not in started:
                started.append(container_name)
                self._write_data(data)

    def get_started_containers(self) -> list[str]:
        """Return the list of containers started in this test session."""
        with filelock.FileLock(str(self.lock_file), timeout=30):
            data = self._read_data()
            return list(data.get("containers_started", []))

    def cleanup_files(self) -> None:
        """Remove session registry and lock files."""
        for path in (self.registry_file, self.lock_file):
            try:
                if path.exists():
                    path.unlink()
            except OSError:
                pass


class SessionContainerManager:
    """Manages database containers across pytest-xdist workers.

    Uses double-checked file locking to coordinate container startup between
    parallel workers, ensuring only one worker starts each container and
    others reuse the running instance.
    """

    def __init__(self) -> None:
        self.worker_id = get_xdist_worker_id()
        self.runtime = ContainerRuntime()
        self.lock_dir = Path(tempfile.gettempdir()) / "pytest-dma-locks"
        self.lock_dir.mkdir(exist_ok=True, parents=True)
        self.registry = SessionRegistry()

    def get_lock_path(self, name: str) -> Path:
        """Get the lock file path for a container name."""
        return self.lock_dir / f"{name}.lock"

    def ensure_postgres(self, config: PostgresDatabaseConfig) -> PostgreSQLDatabase:
        """Ensure a PostgreSQL container is running and healthy."""
        db = PostgreSQLDatabase(self.runtime, config)
        if self.runtime.container_running(config.container_name) and db.is_healthy():
            if config.host_port is None:
                config.host_port = db._get_allocated_port()
            self.registry.record_container_started(config.container_name)
            return db

        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)), timeout=360)
        with lock:
            if self.runtime.container_running(config.container_name) and db.is_healthy():
                if config.host_port is None:
                    config.host_port = db._get_allocated_port()
            else:
                self._start_with_retry(db, PostgresContainerStartError)
            self.registry.record_container_started(config.container_name)

        return db

    def ensure_mysql(self, config: MySQLDatabaseConfig) -> MySQLDatabase:
        """Ensure a MySQL container is running and healthy."""
        db = MySQLDatabase(self.runtime, config)
        if self.runtime.container_running(config.container_name) and db.is_healthy():
            if config.host_port is None:
                config.host_port = db._get_allocated_port()
            self.registry.record_container_started(config.container_name)
            return db

        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)), timeout=360)
        with lock:
            if self.runtime.container_running(config.container_name) and db.is_healthy():
                if config.host_port is None:
                    config.host_port = db._get_allocated_port()
            else:
                self._start_with_retry(db, MySQLContainerStartError)
            self.registry.record_container_started(config.container_name)

        return db

    def ensure_oracle(self, config: OracleDatabaseConfig) -> OracleDatabase:
        """Ensure an Oracle container is running and healthy."""
        db = OracleDatabase(self.runtime, config)
        if self.runtime.container_running(config.container_name) and db.is_healthy():
            if config.host_port is None:
                config.host_port = db._get_allocated_port()
            self.registry.record_container_started(config.container_name)
            return db

        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)), timeout=360)
        with lock:
            if self.runtime.container_running(config.container_name) and db.is_healthy():
                if config.host_port is None:
                    config.host_port = db._get_allocated_port()
            else:
                self._start_with_retry(db, OracleContainerStartError)
            self.registry.record_container_started(config.container_name)

        return db

    def ensure_sqlserver(self, config: SQLServerDatabaseConfig) -> SQLServerDatabase:
        """Ensure a SQL Server container is running and healthy."""
        db = SQLServerDatabase(self.runtime, config)
        if self.runtime.container_running(config.container_name) and db.is_healthy():
            if config.host_port is None:
                config.host_port = db._get_allocated_port()
            self.registry.record_container_started(config.container_name)
            return db

        lock = filelock.FileLock(str(self.get_lock_path(config.container_name)), timeout=360)
        with lock:
            if self.runtime.container_running(config.container_name) and db.is_healthy():
                if config.host_port is None:
                    config.host_port = db._get_allocated_port()
            else:
                self._start_with_retry(db, SQLServerContainerStartError)
            self.registry.record_container_started(config.container_name)

        return db

    @staticmethod
    def _start_with_retry(
        db: PostgreSQLDatabase | MySQLDatabase | OracleDatabase | SQLServerDatabase,
        error_cls: type[Exception],
        max_attempts: int = 3,
    ) -> None:
        """Start a database container, retrying on transient dynamic port conflicts."""
        for attempt in range(max_attempts):
            try:
                db.start(pull=False, recreate=attempt > 0)
            except error_cls:
                if attempt + 1 >= max_attempts:
                    raise
                db.config.host_port = None
                time.sleep(1)
            else:
                return


@pytest.fixture(scope="session")
def container_manager() -> Generator[SessionContainerManager, None, None]:
    """Session-scoped container manager for database containers."""
    manager = SessionContainerManager()

    if not manager.runtime.is_available():
        pytest.skip("No container runtime (Docker/Podman) available")

    yield manager


@pytest.fixture(scope="session", params=POSTGRES_VERSIONS, ids=slugify)
def postgres_collector_db(
    request: pytest.FixtureRequest,
    container_manager: SessionContainerManager,
) -> Generator[PostgreSQLDatabase, None, None]:
    """Session-scoped PostgreSQL database container.

    Parameterized to test against multiple PostgreSQL versions.
    Uses dynamic loopback port allocation to avoid conflicts.
    PostgreSQL 18+ mounts "/var/lib/postgresql" instead of "/var/lib/postgresql/data".
    """
    image = request.param
    version_tag = slugify(image)

    postgres_integration_dir = Path(__file__).parent / "integration" / "postgres"
    dockerfile_path = postgres_integration_dir / "Dockerfile"

    if dockerfile_path.exists():
        version_match = re.search(r":(\d+)", image)
        if version_match:
            pg_version = version_match.group(1)
            pg_major = int(pg_version)
            custom_image = f"dma-test-postgres-pglogical:{pg_version}"
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

    yield container_manager.ensure_postgres(config)


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

    yield container_manager.ensure_mysql(config)


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

    yield container_manager.ensure_oracle(config)


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

    yield container_manager.ensure_sqlserver(config)


def pytest_sessionfinish(session: pytest.Session, exitstatus: int) -> None:
    """Clean up test containers at the end of the session.

    Only the master xdist process performs cleanup, and only when containers
    were actually started during the session and DMA_TEST_KEEP_CONTAINER is unset.
    """
    if not is_xdist_master():
        return

    registry = SessionRegistry()
    started_containers = registry.get_started_containers()
    registry.cleanup_files()

    if not started_containers:
        return

    keep_container = os.environ.get("DMA_TEST_KEEP_CONTAINER", "").lower() in {"1", "true", "yes"}
    if keep_container:
        return

    try:
        runtime = ContainerRuntime()
    except NoRuntimeAvailableError:
        return

    if not runtime.is_available():
        return

    cmd = runtime.get_runtime_command()

    containers = runtime.list_containers(include_all=True)
    test_containers = [c for c in containers if c in started_containers or c.startswith("dma-test-")]
    if test_containers:
        subprocess.run([cmd, "rm", "-f", *test_containers], capture_output=True, check=False)

    keep_volumes = os.environ.get("DMA_TEST_KEEP_VOLUMES", "").lower() in {"1", "true", "yes"}
    if not keep_volumes:
        volumes = runtime.list_volumes()
        test_volumes = [v for v in volumes if v.startswith("dma-test-")]
        if test_volumes:
            subprocess.run([cmd, "volume", "rm", "-f", *test_volumes], capture_output=True, check=False)


def pytest_collection_modifyitems(config: pytest.Config, items: list[pytest.Item]) -> None:
    """Add xdist_group markers based on database type and version.

    This ensures tests for the same database version run on the same worker
    and are serialized, preventing test interference on shared database state.
    """
    for item in items:
        if not hasattr(item, "fixturenames"):
            continue

        group_suffix = ""
        if hasattr(item, "callspec") and hasattr(item.callspec, "params"):
            for param_name, param_value in item.callspec.params.items():
                if "collector_db" in param_name and param_value:
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
