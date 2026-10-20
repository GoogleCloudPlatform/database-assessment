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
"""Shared base classes and exceptions for database container management."""

from __future__ import annotations

import subprocess
import time
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from typing import TYPE_CHECKING, Generic, TypeVar

if TYPE_CHECKING:
    from pathlib import Path

    from tools.lib.container import ContainerRuntime

__all__ = [
    "BaseDatabaseConfig",
    "ContainerAlreadyRunningError",
    "ContainerStartError",
    "DatabaseContainer",
    "DatabaseError",
]


class DatabaseError(Exception):
    """Base exception for database container errors."""


class ContainerAlreadyRunningError(DatabaseError):
    """Raised when a container is already running."""

    def __init__(self, container_name: str) -> None:
        super().__init__(f"Container '{container_name}' is already running.")
        self.container_name = container_name


class ContainerStartError(DatabaseError):
    """Raised when a container fails to start or pass health checks."""

    def __init__(self, message: str, *, container_name: str | None = None, logs: str | None = None) -> None:
        super().__init__(message)
        self.container_name = container_name
        self.logs = logs


@dataclass
class BaseDatabaseConfig:
    """Base configuration shared by all database containers.

    Attributes:
        container_name: Name for the container.
        image: Container image to run.
        hostname: Container hostname.
        host_port: Host port to bind, or None for dynamic loopback allocation.
        container_port: Port exposed inside the container.
        data_volume_name: Name of the persistent data volume.
        health_interval: Health check interval in seconds.
        health_timeout: Health check timeout in seconds.
        health_retries: Number of health check retries before failure.
        restart_policy: Container restart policy.
        build_context: Optional directory containing a Dockerfile for custom image builds.
        dockerfile: Optional path to a Dockerfile.
        build_args: Build arguments passed when building a custom image.
        extra_env: Additional environment variables passed to the container.
        extra_command: Additional command arguments appended to the container entrypoint.
    """

    container_name: str = "dma-test-db"
    image: str = ""
    hostname: str = "db"
    host_port: int | None = None
    container_port: int = 0
    data_volume_name: str = "dma-test-db-data"
    health_interval: int = 10
    health_timeout: int = 5
    health_retries: int = 10
    restart_policy: str = "unless-stopped"
    build_context: Path | None = None
    dockerfile: Path | None = None
    build_args: dict[str, str] = field(default_factory=dict)
    extra_env: dict[str, str] = field(default_factory=dict)
    extra_command: list[str] = field(default_factory=list)


ConfigT = TypeVar("ConfigT", bound=BaseDatabaseConfig)


class DatabaseContainer(ABC, Generic[ConfigT]):
    """Abstract base manager for a database container lifecycle."""

    default_config_factory: type[ConfigT]
    run_timeout_seconds: int = 60
    health_poll_interval_seconds: int = 2
    stop_timeout_seconds: int = 10
    failure_log_tail_lines: int = 50

    def __init__(self, runtime: ContainerRuntime, config: ConfigT | None = None) -> None:
        """Initialize the database container manager.

        Args:
            runtime: Container runtime instance.
            config: Database configuration. Uses engine defaults if not provided.
        """
        self.runtime = runtime
        self.config: ConfigT = config if config is not None else self.default_config_factory()

    def start(self, *, pull: bool = False, recreate: bool = False) -> None:
        """Start the database container and wait until it is healthy.

        Args:
            pull: Pull the image before starting (ignored when build_context is set).
            recreate: Remove any existing container before starting.

        Raises:
            ContainerAlreadyRunningError: If container is already running and recreate is False.
            ContainerStartError: If image build/pull, container start, port lookup, or health check fails.
        """
        config = self.config

        if self.runtime.container_running(config.container_name):
            if not recreate:
                raise ContainerAlreadyRunningError(config.container_name)
            self.remove(force=True)
        elif self.runtime.container_exists(config.container_name):
            if recreate:
                self.remove(force=True)
            else:
                try:
                    self.runtime.start_container(config.container_name)
                except (subprocess.SubprocessError, OSError) as exc:
                    msg = f"Failed to start existing container '{config.container_name}': {exc}"
                    raise ContainerStartError(msg, container_name=config.container_name) from exc
                allocated_port = self.get_allocated_port()
                self._wait_for_health()
                self.config.host_port = allocated_port
                return

        try:
            if config.build_context is not None:
                self._build_image()
            elif pull:
                self.runtime.pull_image(config.image)
            self.runtime.create_volume(config.data_volume_name)
        except (subprocess.SubprocessError, OSError) as exc:
            msg = f"Failed to prepare image or volume for '{config.container_name}': {exc}"
            raise ContainerStartError(msg, container_name=config.container_name) from exc

        run_args = self._build_run_args()

        try:
            self.runtime.run_command(run_args, timeout=self.run_timeout_seconds)
        except (subprocess.SubprocessError, OSError) as exc:
            logs = (
                self.runtime.get_container_logs(config.container_name, tail=self.failure_log_tail_lines)
                if self.runtime.container_exists(config.container_name)
                else ""
            )
            msg = f"Failed to start container: {exc}"
            raise ContainerStartError(msg, container_name=config.container_name, logs=logs) from exc

        allocated_port = config.host_port if config.host_port is not None else self.get_allocated_port()
        self._wait_for_health()
        self.config.host_port = allocated_port

    def get_allocated_port(self) -> int:
        """Return the dynamically allocated host port mapped to the container port.

        Returns:
            The allocated host port number.

        Raises:
            ContainerStartError: If the mapped host port cannot be determined.
        """
        for _ in range(10):
            port = self.runtime.get_container_port(self.config.container_name, self.config.container_port)
            if port is not None:
                return port
            time.sleep(0.1)
        msg = f"Failed to get allocated port for container '{self.config.container_name}'"
        raise ContainerStartError(msg, container_name=self.config.container_name)

    @abstractmethod
    def is_healthy(self) -> bool:
        """Check whether the database inside the container is ready for connections."""

    def is_running(self) -> bool:
        """Check whether the container is currently running."""
        return self.runtime.container_running(self.config.container_name)

    def stop(self, *, timeout: int | None = None) -> None:
        """Stop the database container.

        Args:
            timeout: Seconds to wait before killing the container.
        """
        effective_timeout = timeout if timeout is not None else self.stop_timeout_seconds
        self.runtime.stop_container(self.config.container_name, timeout=effective_timeout)

    def restart(self) -> None:
        """Restart the database container and wait for health."""
        try:
            self.runtime.run_command(["restart", self.config.container_name])
        except (subprocess.SubprocessError, OSError) as exc:
            msg = f"Failed to restart container '{self.config.container_name}': {exc}"
            raise ContainerStartError(msg, container_name=self.config.container_name) from exc
        allocated_port = self.get_allocated_port()
        self._wait_for_health()
        self.config.host_port = allocated_port

    def remove(self, *, force: bool = False, remove_volume: bool = False) -> None:
        """Remove the database container and optionally its data volume.

        Args:
            force: Force removal of a running container.
            remove_volume: Also remove the persistent data volume.
        """
        self.runtime.remove_container(self.config.container_name, force=force)
        if remove_volume:
            self.runtime.remove_volume(self.config.data_volume_name, force=force)

    def logs(self, *, tail: int | None = None) -> str:
        """Return container logs.

        Args:
            tail: Number of lines from the end to return.

        Returns:
            Container stdout and stderr logs.
        """
        return self.runtime.get_container_logs(self.config.container_name, tail=tail)

    def _build_image(self) -> None:
        """Build a custom container image when build_context is configured."""
        config = self.config
        if config.build_context is None:
            return
        self.runtime.build_image(
            tag=config.image,
            context=config.build_context,
            dockerfile=config.dockerfile,
            build_args=config.build_args,
        )

    @abstractmethod
    def _build_run_args(self) -> list[str]:
        """Construct the container runtime ``run`` arguments for this database engine."""

    def _append_common_run_args(
        self,
        *,
        volume_mount: str,
        env_vars: list[str],
        health_cmd: str,
    ) -> list[str]:
        """Build the standard ``run`` argument list shared by all database containers.

        Binds host ports to ``127.0.0.1`` to prevent wildcard interface collisions
        when starting multiple containers in parallel under ``pytest-xdist``.
        """
        config = self.config
        args = [
            "run",
            "-d",
            "--name",
            config.container_name,
            "--hostname",
            config.hostname,
            "-v",
            volume_mount,
        ]
        for env_entry in env_vars:
            args.extend(["-e", env_entry])

        args.extend([
            "--restart",
            config.restart_policy,
            "--health-cmd",
            health_cmd,
            "--health-interval",
            f"{config.health_interval}s",
            "--health-timeout",
            f"{config.health_timeout}s",
            "--health-retries",
            str(config.health_retries),
        ])

        if config.host_port is not None:
            args.extend(["-p", f"127.0.0.1:{config.host_port}:{config.container_port}"])
        else:
            args.extend(["-p", f"127.0.0.1::{config.container_port}"])

        for key, value in config.extra_env.items():
            args.extend(["-e", f"{key}={value}"])

        args.append(config.image)

        if config.extra_command:
            args.extend(config.extra_command)

        return args

    def _wait_for_health(self) -> None:
        """Poll ``is_healthy()`` until the database is ready or timeout/exit occurs.

        Raises:
            ContainerStartError: If the container exits prematurely or health check times out.
        """
        config = self.config
        max_wait = config.health_interval * config.health_retries
        waited = 0
        poll_interval = self.health_poll_interval_seconds

        while waited < max_wait:
            if not self.is_running():
                logs = self.runtime.get_container_logs(config.container_name, tail=self.failure_log_tail_lines)
                msg = f"Container '{config.container_name}' exited before becoming healthy."
                raise ContainerStartError(msg, container_name=config.container_name, logs=logs)
            if self.is_healthy():
                return
            time.sleep(poll_interval)
            waited += poll_interval

        logs = self.runtime.get_container_logs(config.container_name, tail=self.failure_log_tail_lines)
        msg = f"Database health check timed out after {max_wait}s. Check container logs for details."
        raise ContainerStartError(msg, container_name=config.container_name, logs=logs)
