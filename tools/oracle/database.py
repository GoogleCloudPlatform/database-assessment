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
"""Oracle database container management."""

from __future__ import annotations

import subprocess
import time
from dataclasses import dataclass, field
from typing import TYPE_CHECKING

if TYPE_CHECKING:
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
    """Configuration for an Oracle database container.

    Uses gvenzl/oracle-xe or gvenzl/oracle-free images which provide
    pre-configured Oracle XE/Free instances.

    Attributes:
        container_name: Name for the container.
        image: Docker image to use (e.g., gvenzl/oracle-xe:18-slim-faststart).
        hostname: Container hostname.
        host_port: Host port to bind. None for dynamic allocation.
        container_port: Port inside the container.
        oracle_password: Password for SYS, SYSTEM, and PDBADMIN users.
        app_user: Application user name.
        app_user_password: Password for the application user.
        data_volume_name: Name of the data volume.
        health_interval: Health check interval in seconds.
        health_timeout: Health check timeout in seconds.
        health_retries: Number of health check retries.
        restart_policy: Container restart policy.
        extra_env: Additional environment variables.
    """

    container_name: str = "dma-test-oracle"
    image: str = "gvenzl/oracle-free:23-slim-faststart"
    hostname: str = "db"
    host_port: int | None = None
    container_port: int = 1521
    oracle_password: str = "super-secret"
    app_user: str = "app"
    app_user_password: str = "super-secret"
    data_volume_name: str = "dma-test-oracle-data"
    # Oracle needs longer timeouts - startup can take 2-5 minutes
    health_interval: int = 15
    health_timeout: int = 10
    health_retries: int = 30  # 7.5 minutes max wait
    restart_policy: str = "unless-stopped"
    extra_env: dict[str, str] = field(default_factory=dict)


class OracleDatabase:
    """Manages an Oracle database container.

    This class provides lifecycle management for Oracle containers using
    the gvenzl/oracle-xe or gvenzl/oracle-free images, which provide
    lightweight Oracle XE/Free instances.
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

        Note: Oracle containers can take 2-5 minutes to fully start.
        The health check is configured with extended timeouts to accommodate this.

        Args:
            pull: Pull the image before starting.
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
                self._wait_for_health()
                return

        # Pull image if requested
        if pull:
            self.runtime.pull_image(config.image)

        # Create data volume
        self.runtime.create_volume(config.data_volume_name)

        # Build run command
        run_args = self._build_run_args()

        try:
            self.runtime.run_command(run_args, timeout=120)
        except subprocess.CalledProcessError as e:
            logs = (
                self.runtime.get_container_logs(config.container_name, tail=50)
                if self.runtime.container_exists(config.container_name)
                else ""
            )
            raise ContainerStartError(
                f"Failed to start container: {e}",
                container_name=config.container_name,
                logs=logs,
            ) from e

        # Get allocated port if dynamic
        if config.host_port is None:
            self.config.host_port = self._get_allocated_port()

        # Wait for database to be ready
        self._wait_for_health()

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
            f"{config.data_volume_name}:/opt/oracle/oradata",
            "-e",
            f"ORACLE_PASSWORD={config.oracle_password}",
            "-e",
            f"APP_USER={config.app_user}",
            "-e",
            f"APP_USER_PASSWORD={config.app_user_password}",
            "--restart",
            config.restart_policy,
            # The gvenzl images provide a built-in healthcheck.sh script
            "--health-cmd",
            "healthcheck.sh",
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

        return args

    def _get_allocated_port(self) -> int:
        """Get the dynamically allocated host port.

        Returns:
            The allocated host port number.

        Raises:
            ContainerStartError: If port cannot be determined.
        """
        port = self.runtime.get_container_port(self.config.container_name, self.config.container_port)
        if port is None:
            raise ContainerStartError(
                f"Failed to get allocated port for container '{self.config.container_name}'",
                container_name=self.config.container_name,
            )
        return port

    def _wait_for_health(self) -> None:
        """Wait for the database to be healthy.

        Oracle databases can take several minutes to start. This method
        polls the health check until the database is ready or timeout occurs.

        Raises:
            ContainerStartError: If health check times out.
        """
        config = self.config
        max_wait = config.health_interval * config.health_retries
        waited = 0
        poll_interval = 5  # Longer poll interval for Oracle

        while waited < max_wait:
            if self.is_healthy():
                return
            time.sleep(poll_interval)
            waited += poll_interval

        logs = self.runtime.get_container_logs(config.container_name, tail=100)
        raise ContainerStartError(
            f"Database health check timed out after {max_wait}s. "
            "Oracle databases typically take 2-5 minutes to start. "
            "Check container logs for details.",
            container_name=config.container_name,
            logs=logs,
        )

    def is_healthy(self) -> bool:
        """Check if the database is healthy and accepting connections."""
        try:
            returncode, _, _ = self.runtime.run_command(
                ["exec", self.config.container_name, "healthcheck.sh"],
                check=False,
            )
            return returncode == 0
        except (subprocess.SubprocessError, OSError):
            return False

    def is_running(self) -> bool:
        """Check if the container is running."""
        return self.runtime.container_running(self.config.container_name)

    def stop(self, *, timeout: int = 30) -> None:
        """Stop the database container.

        Args:
            timeout: Seconds to wait before killing the container.
                     Oracle needs more time for graceful shutdown.
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
