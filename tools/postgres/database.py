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
"""PostgreSQL database container management."""

from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pathlib import Path

    from tools.lib.container import ContainerRuntime


class DatabaseError(Exception):
    """Base exception for database errors."""


class ContainerAlreadyRunningError(DatabaseError):
    """Raised when a container is already running."""

    def __init__(self, container_name: str) -> None:
        super().__init__(f"Container '{container_name}' is already running.")
        self.container_name = container_name


class ContainerStartError(DatabaseError):
    """Raised when a container fails to start."""

    def __init__(self, message: str, *, container_name: str | None = None, logs: str | None = None) -> None:
        super().__init__(message)
        self.container_name = container_name
        self.logs = logs


@dataclass
class DatabaseConfig:
    """Configuration for a PostgreSQL database container.

    Attributes:
        container_name: Name for the container.
        image: Docker image to use. Ignored if build_context is set.
        hostname: Container hostname.
        host_port: Host port to bind. None for dynamic allocation.
        container_port: Port inside the container.
        postgres_password: Password for the postgres user.
        postgres_user: Username for the primary user.
        postgres_db: Name of the default database.
        data_volume_name: Name of the data volume.
        health_interval: Health check interval in seconds.
        health_timeout: Health check timeout in seconds.
        health_retries: Number of health check retries.
        restart_policy: Container restart policy.
        build_context: Directory containing Dockerfile for building custom image.
        dockerfile: Path to Dockerfile relative to build_context.
        build_args: Arguments to pass during image build.
        extra_env: Additional environment variables.
        extra_command: Additional command arguments for postgres.
    """

    container_name: str = "dma-test-postgres"
    image: str = "postgres:latest"
    hostname: str = "db"
    host_port: int | None = None
    container_port: int = 5432
    postgres_password: str = "super-secret"
    postgres_user: str = "postgres"
    postgres_db: str = "postgres"
    data_volume_name: str = "dma-test-postgres-data"
    health_interval: int = 10
    health_timeout: int = 5
    health_retries: int = 10
    restart_policy: str = "unless-stopped"
    build_context: Path | None = None
    dockerfile: Path | None = None
    build_args: dict[str, str] = field(default_factory=dict)
    extra_env: dict[str, str] = field(default_factory=dict)
    extra_command: list[str] = field(default_factory=list)
    data_mount_path: str = "/var/lib/postgresql/data"  # For PG 18+, use "/var/lib/postgresql"


class PostgreSQLDatabase:
    """Manages a PostgreSQL database container.

    This class provides lifecycle management for PostgreSQL containers,
    including starting, stopping, health checking, and port allocation.
    """

    def __init__(self, runtime: ContainerRuntime, config: DatabaseConfig | None = None) -> None:
        """Initialize the database manager.

        Args:
            runtime: Container runtime instance.
            config: Database configuration. Uses defaults if not provided.
        """
        self.runtime = runtime
        self.config = config or DatabaseConfig()

    def start(self, *, pull: bool = False, recreate: bool = False) -> None:
        """Start the database container.

        Args:
            pull: Pull the image before starting (ignored if build_context is set).
            recreate: Remove existing container before starting.

        Raises:
            ContainerAlreadyRunningError: If container is running and recreate=False.
            ContainerStartError: If container fails to start.
        """
        config = self.config

        # Handle existing container
        if self.runtime.container_running(config.container_name):
            if not recreate:
                raise ContainerAlreadyRunningError(config.container_name)
            self.remove(force=True)
        elif self.runtime.container_exists(config.container_name):
            if recreate:
                self.remove(force=True)
            else:
                # Start existing stopped container
                self.runtime.start_container(config.container_name)
                if config.host_port is None:
                    self.config.host_port = self._get_allocated_port()
                self._wait_for_health()
                return

        # Build or pull image
        if config.build_context is not None:
            self._build_image()
        elif pull:
            self.runtime.pull_image(config.image)

        # Create data volume
        self.runtime.create_volume(config.data_volume_name)

        # Build run command
        run_args = self._build_run_args()

        try:
            self.runtime.run_command(run_args, timeout=60)
        except subprocess.CalledProcessError as e:
            logs = (
                self.runtime.get_container_logs(config.container_name, tail=50)
                if self.runtime.container_exists(config.container_name)
                else ""
            )
            msg = f"Failed to start container: {e}"
            raise ContainerStartError(msg, container_name=config.container_name, logs=logs) from e

        # Get allocated port if dynamic
        if config.host_port is None:
            self.config.host_port = self._get_allocated_port()

        # Wait for database to be ready
        self._wait_for_health()

    def _build_image(self) -> None:
        """Build a custom PostgreSQL image."""
        config = self.config
        if config.build_context is None:
            return

        self.runtime.build_image(
            tag=config.image,
            context=config.build_context,
            dockerfile=config.dockerfile,
            build_args=config.build_args,
        )

    def _build_run_args(self) -> list[str]:
        """Build the docker run command arguments."""
        config = self.config

        args = [
            "run",
            "-d",
            "--name",
            config.container_name,
            "--hostname",
            config.hostname,
            "-v",
            f"{config.data_volume_name}:{config.data_mount_path}",
            "-e",
            f"POSTGRES_PASSWORD={config.postgres_password}",
            "-e",
            f"POSTGRES_USER={config.postgres_user}",
            "-e",
            f"POSTGRES_DB={config.postgres_db}",
            "--restart",
            config.restart_policy,
            "--health-cmd",
            f"pg_isready -U {config.postgres_user} -d {config.postgres_db}",
            "--health-interval",
            f"{config.health_interval}s",
            "--health-timeout",
            f"{config.health_timeout}s",
            "--health-retries",
            str(config.health_retries),
        ]

        # Port mapping
        if config.host_port is not None:
            args.extend(["-p", f"{config.host_port}:{config.container_port}"])
        else:
            args.extend(["-p", str(config.container_port)])

        # Additional environment variables
        for key, value in config.extra_env.items():
            args.extend(["-e", f"{key}={value}"])

        # Image
        args.append(config.image)

        # Additional postgres command arguments
        if config.extra_command:
            args.extend(config.extra_command)

        return args

    def _get_allocated_port(self) -> int:
        """Get the dynamically allocated host port.

        Returns:
            The allocated host port number.

        Raises:
            ContainerStartError: If port cannot be determined.
        """
        for _ in range(10):
            port = self.runtime.get_container_port(self.config.container_name, self.config.container_port)
            if port is not None:
                return port
            time.sleep(0.1)
        msg = f"Failed to get allocated port for container '{self.config.container_name}'"
        raise ContainerStartError(msg, container_name=self.config.container_name)

    def _wait_for_health(self) -> None:
        """Wait for the database to be healthy.

        Raises:
            ContainerStartError: If health check times out.
        """
        config = self.config
        max_wait = config.health_interval * config.health_retries
        waited = 0
        poll_interval = 2

        while waited < max_wait:
            if self.is_healthy():
                return
            time.sleep(poll_interval)
            waited += poll_interval

        logs = self.runtime.get_container_logs(config.container_name, tail=50)
        msg = f"Database health check timed out after {max_wait}s. Check container logs for details."
        raise ContainerStartError(msg, container_name=config.container_name, logs=logs)

    def is_healthy(self) -> bool:
        """Check if the database is healthy and accepting connections."""
        try:
            _, stdout, _ = self.runtime.run_command(
                [
                    "exec",
                    self.config.container_name,
                    "pg_isready",
                    "-U",
                    self.config.postgres_user,
                    "-d",
                    self.config.postgres_db,
                ],
                check=False,
            )
        except (subprocess.SubprocessError, OSError):
            return False
        return "accepting connections" in stdout

    def is_running(self) -> bool:
        """Check if the container is running."""
        return self.runtime.container_running(self.config.container_name)

    def stop(self, *, timeout: int = 10) -> None:
        """Stop the database container.

        Args:
            timeout: Seconds to wait before killing the container.
        """
        self.runtime.stop_container(self.config.container_name, timeout=timeout)

    def restart(self) -> None:
        """Restart the database container."""
        self.runtime.run_command(["restart", self.config.container_name])
        self._wait_for_health()

    def remove(self, *, force: bool = False, remove_volume: bool = False) -> None:
        """Remove the database container.

        Args:
            force: Force removal of running container.
            remove_volume: Also remove the data volume.
        """
        self.runtime.remove_container(self.config.container_name, force=force)
        if remove_volume:
            self.runtime.remove_volume(self.config.data_volume_name, force=force)

    def logs(self, *, tail: int | None = None) -> str:
        """Get container logs.

        Args:
            tail: Number of lines from the end to return.

        Returns:
            Container logs as a string.
        """
        return self.runtime.get_container_logs(self.config.container_name, tail=tail)
