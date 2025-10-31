"""Pytest plugin for managing database containers."""

from __future__ import annotations

import time
from collections.abc import Callable
from typing import Any

import pytest
from tools.lib.container import ContainerRuntime


@pytest.fixture(scope="session")
def container_runtime() -> ContainerRuntime:
    """Returns a container runtime instance."""
    return ContainerRuntime()


@pytest.fixture(scope="session")
def database_container(
    request: pytest.FixtureRequest, container_runtime: ContainerRuntime
) -> Callable[..., dict[str, Any]]:
    """A factory fixture that can start and manage database containers."""

    def _database_container(
        image: str,
        name: str,
        host_port: int,
        container_port: int,
        env: dict[str, str],
        health_check: Callable[[], bool],
    ) -> dict[str, Any]:
        """Starts a container and returns its details, with cleanup registered."""
        if container_runtime.container_exists(name):
            container_runtime.run_command(["stop", name])
            container_runtime.run_command(["rm", name])

        def cleanup() -> None:
            """Stop and remove the container."""
            container_runtime.run_command(["stop", name], check=False)
            container_runtime.run_command(["rm", name], check=False)

        request.addfinalizer(cleanup)

        run_args = ["run", "-d", "--name", name]
        run_args.extend(["-p", f"{host_port}:{container_port}"])
        for key, value in env.items():
            run_args.extend(["-e", f"{key}={value}"])
        run_args.append(image)

        container_runtime.run_command(run_args)

        # Wait for the container to be healthy
        for _ in range(30):
            if health_check():
                break
            time.sleep(1)
        else:
            pytest.fail(f"Container {name} did not become healthy in time.")

        return {
            "name": name,
            "host_port": host_port,
            "container_port": container_port,
            "env": env,
        }

    return _database_container


@pytest.fixture(scope="session")
def mysql8_service(database_container: Callable[..., dict[str, Any]]) -> dict[str, Any]:
    """Starts the mysql8 service."""
    from tools.mysql.health import HealthChecker

    def health_check() -> bool:
        """Checks if the mysql container is healthy."""
        checker = HealthChecker()
        health = checker.check_connectivity()
        return health.status == "healthy"

    return database_container(
        image="mysql:latest",
        name="mysql8-test",
        host_port=3306,
        container_port=3306,
        env={
            "MYSQL_ROOT_PASSWORD": "super-secret",
            "MYSQL_PASSWORD": "super-secret",
            "MYSQL_USER": "app",
            "MYSQL_DATABASE": "db",
            "MYSQL_ROOT_HOST": "%",
            "LANG": "C.UTF-8",
        },
        health_check=health_check,
    )


@pytest.fixture(scope="session")
def oracle18c_service(database_container: Callable[..., dict[str, Any]]) -> dict[str, Any]:
    """Starts the oracle18c service."""
    from tools.oracle.health import HealthChecker

    def health_check() -> bool:
        """Checks if the oracle container is healthy."""
        checker = HealthChecker()
        health = checker.check_connectivity()
        return health.status == "healthy"

    return database_container(
        image="gvenzl/oracle-xe:18-slim-faststart",
        name="oracle18c-test",
        host_port=1521,
        container_port=1521,
        env={
            "ORACLE_PASSWORD": "super-secret",
            "APP_USER_PASSWORD": "super-secret",
            "APP_USER": "app",
        },
        health_check=health_check,
    )


@pytest.fixture(scope="session")
def mssql_service(database_container: Callable[..., dict[str, Any]]) -> dict[str, Any]:
    """Starts the mssql service."""
    from tools.sqlserver.health import HealthChecker

    def health_check() -> bool:
        """Checks if the mssql container is healthy."""
        checker = HealthChecker()
        health = checker.check_connectivity()
        return health.status == "healthy"

    return database_container(
        image="mcr.microsoft.com/mssql/server:2022-latest",
        name="mssql-test",
        host_port=1433,
        container_port=1433,
        env={
            "SA_PASSWORD": "Super-secret1",
            "MSSQL_PID": "Developer",
            "ACCEPT_EULA": "Y",
        },
        health_check=health_check,
    )
