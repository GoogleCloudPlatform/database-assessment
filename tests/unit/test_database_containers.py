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
"""Unit tests for database container lifecycle management and test session coordination."""

from __future__ import annotations

import subprocess
from unittest.mock import MagicMock

import pytest

from tests.database import SessionContainerManager, slugify
from tools.lib.container import ContainerRuntime
from tools.lib.database import ContainerAlreadyRunningError, ContainerStartError
from tools.mysql.database import DatabaseConfig as MySQLDatabaseConfig
from tools.mysql.database import MySQLDatabase
from tools.oracle.database import DatabaseConfig as OracleDatabaseConfig
from tools.oracle.database import OracleDatabase
from tools.postgres.database import DatabaseConfig as PostgresDatabaseConfig
from tools.postgres.database import PostgreSQLDatabase
from tools.sqlserver.database import DatabaseConfig as SQLServerDatabaseConfig
from tools.sqlserver.database import SQLServerDatabase


def test_slugify_strips_registry_prefix_and_normalizes() -> None:
    assert slugify("postgres:17") == "postgres-17"
    assert slugify("gvenzl/oracle-free:23-slim-faststart") == "oracle-free-23-slim-faststart"
    assert slugify("mcr.microsoft.com/mssql/server:2022-latest") == "server-2022-latest"


def test_postgres_build_run_args_binds_loopback_and_healthcheck() -> None:
    runtime = MagicMock(spec=ContainerRuntime)
    config = PostgresDatabaseConfig(
        container_name="pg-unit",
        image="postgres:17",
        host_port=None,
        extra_env={"TZ": "UTC"},
        extra_command=["-c", "wal_level=logical"],
    )
    db = PostgreSQLDatabase(runtime, config)
    run_args = db._build_run_args()

    assert "127.0.0.1::5432" in run_args
    assert "TZ=UTC" in run_args
    assert run_args[-2:] == ["-c", "wal_level=logical"]


def test_mysql_oracle_and_sqlserver_build_run_args() -> None:
    runtime = MagicMock(spec=ContainerRuntime)

    mysql_db = MySQLDatabase(runtime, MySQLDatabaseConfig(host_port=13306))
    mysql_args = mysql_db._build_run_args()
    assert "127.0.0.1:13306:3306" in mysql_args
    assert "mysqladmin ping -h 127.0.0.1 --protocol=TCP" in mysql_args

    oracle_db = OracleDatabase(runtime, OracleDatabaseConfig())
    oracle_args = oracle_db._build_run_args()
    assert "127.0.0.1::1521" in oracle_args
    assert "healthcheck.sh" in oracle_args

    sqlserver_db = SQLServerDatabase(runtime, SQLServerDatabaseConfig())
    sqlserver_args = sqlserver_db._build_run_args()
    assert "127.0.0.1::1433" in sqlserver_args
    assert "ACCEPT_EULA=Y" in sqlserver_args


def test_wait_for_health_fails_fast_when_container_exits() -> None:
    runtime = MagicMock(spec=ContainerRuntime)
    runtime.container_running.return_value = False
    runtime.get_container_logs.return_value = "FATAL: invalid configuration"

    db = PostgreSQLDatabase(runtime, PostgresDatabaseConfig(container_name="pg-crashed"))

    with pytest.raises(ContainerStartError, match="exited before becoming healthy") as exc_info:
        db._wait_for_health()

    assert exc_info.value.container_name == "pg-crashed"
    assert exc_info.value.logs == "FATAL: invalid configuration"


def test_start_raises_already_running_when_recreate_is_false() -> None:
    runtime = MagicMock(spec=ContainerRuntime)
    runtime.container_running.return_value = True

    db = PostgreSQLDatabase(runtime, PostgresDatabaseConfig(container_name="pg-running"))

    with pytest.raises(ContainerAlreadyRunningError):
        db.start(recreate=False)


def test_start_wraps_subprocess_error_in_container_start_error() -> None:
    runtime = MagicMock(spec=ContainerRuntime)
    runtime.container_running.return_value = False
    runtime.container_exists.return_value = False
    runtime.run_command.side_effect = subprocess.CalledProcessError(125, ["docker", "run"])

    db = PostgreSQLDatabase(runtime, PostgresDatabaseConfig(container_name="pg-fail"))

    with pytest.raises(ContainerStartError, match="Failed to start container"):
        db.start()


def test_session_manager_start_with_retry_recreates_unhealthy_running_container() -> None:
    manager = SessionContainerManager()
    manager.runtime = MagicMock(spec=ContainerRuntime)
    manager.runtime.container_running.return_value = True

    db = MagicMock(spec=PostgreSQLDatabase)
    db.config = PostgresDatabaseConfig(container_name="pg-unhealthy")

    manager._start_with_retry(db, max_attempts=2)

    db.start.assert_called_once_with(pull=False, recreate=True)


def test_session_manager_start_with_retry_cleans_up_on_final_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr("tests.database.time.sleep", lambda _: None)
    manager = SessionContainerManager()
    manager.runtime = MagicMock(spec=ContainerRuntime)
    manager.runtime.container_running.return_value = False

    db = MagicMock(spec=PostgreSQLDatabase)
    db.config = PostgresDatabaseConfig(container_name="pg- doomed", host_port=55432)
    db.start.side_effect = ContainerStartError("bind failed", container_name="pg-doomed")

    with pytest.raises(ContainerStartError, match="bind failed"):
        manager._start_with_retry(db, max_attempts=2)

    assert db.start.call_count == 2
    db.remove.assert_called_once_with(force=True, remove_volume=True)
