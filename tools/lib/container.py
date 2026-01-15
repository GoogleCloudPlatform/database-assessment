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
"""Container runtime abstraction for Docker and Podman."""

from __future__ import annotations

import shutil
import subprocess
from enum import Enum
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    from pathlib import Path


class ContainerRuntimeError(Exception):
    """Base exception for container runtime errors."""


class NoRuntimeAvailableError(ContainerRuntimeError):
    """Raised when neither Docker nor Podman is available."""

    def __init__(self) -> None:
        super().__init__(
            "No container runtime available. "
            "Please install Docker (https://docs.docker.com/get-docker/) "
            "or Podman (https://podman.io/getting-started/installation)."
        )


class ContainerNotFoundError(ContainerRuntimeError):
    """Raised when a container is not found."""

    def __init__(self, container_name: str) -> None:
        super().__init__(f"Container '{container_name}' not found.")
        self.container_name = container_name


class RuntimeType(str, Enum):
    """Container runtime type."""

    DOCKER = "docker"
    PODMAN = "podman"
    NONE = "none"


class ContainerRuntime:
    """Unified interface for Docker and Podman container operations.

    This class auto-detects the available container runtime (Docker or Podman)
    and provides a consistent API for container lifecycle management.
    """

    def __init__(self) -> None:
        self._runtime_type = self.detect_runtime()
        self._command = self._runtime_type.value if self._runtime_type != RuntimeType.NONE else None

    @staticmethod
    def detect_runtime() -> RuntimeType:
        """Detect the available container runtime.

        Checks for Docker first, then Podman. Returns RuntimeType.NONE if
        neither is available or responsive.
        """
        # Check for Docker
        if shutil.which("docker"):
            try:
                result = subprocess.run(
                    ["docker", "--version"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=False,
                )
                if result.returncode == 0:
                    return RuntimeType.DOCKER
            except (subprocess.SubprocessError, OSError):
                pass

        # Check for Podman
        if shutil.which("podman"):
            try:
                result = subprocess.run(
                    ["podman", "--version"],
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=False,
                )
                if result.returncode == 0:
                    return RuntimeType.PODMAN
            except (subprocess.SubprocessError, OSError):
                pass

        return RuntimeType.NONE

    @property
    def runtime_type(self) -> RuntimeType:
        """Return the detected runtime type."""
        return self._runtime_type

    def is_available(self) -> bool:
        """Check if a container runtime is available."""
        return self._runtime_type != RuntimeType.NONE

    def get_runtime_command(self) -> str:
        """Get the runtime command (docker or podman).

        Raises:
            NoRuntimeAvailableError: If no runtime is available.
        """
        if self._command is None:
            raise NoRuntimeAvailableError
        return self._command

    def run_command(
        self,
        args: list[str],
        *,
        capture_output: bool = True,
        check: bool = True,
        timeout: int | None = None,
        cwd: Path | None = None,
    ) -> tuple[int, str, str]:
        """Execute a container runtime command.

        Args:
            args: Command arguments to pass to the runtime.
            capture_output: Whether to capture stdout and stderr.
            check: Whether to raise an exception on non-zero exit code.
            timeout: Command timeout in seconds.
            cwd: Working directory for the command.

        Returns:
            Tuple of (return_code, stdout, stderr).

        Raises:
            NoRuntimeAvailableError: If no runtime is available.
            subprocess.CalledProcessError: If check=True and command fails.
            subprocess.TimeoutExpired: If command times out.
        """
        cmd = self.get_runtime_command()
        full_cmd = [cmd, *args]

        result = subprocess.run(
            full_cmd,
            capture_output=capture_output,
            text=True,
            timeout=timeout,
            check=check,
            cwd=cwd,
        )

        return result.returncode, result.stdout, result.stderr

    def container_exists(self, container_name: str) -> bool:
        """Check if a container exists (running or stopped).

        Uses exact name matching to prevent false positives from substring matches.
        """
        try:
            _, stdout, _ = self.run_command(
                ["ps", "-a", "--filter", f"name=^{container_name}$", "--format", "{{.Names}}"],
                check=False,
            )
            return container_name in stdout.strip().split("\n")
        except (subprocess.SubprocessError, OSError):
            return False

    def container_running(self, container_name: str) -> bool:
        """Check if a container is currently running.

        Uses exact name matching to prevent false positives from substring matches.
        """
        try:
            _, stdout, _ = self.run_command(
                ["ps", "--filter", f"name=^{container_name}$", "--format", "{{.Names}}"],
                check=False,
            )
            return container_name in stdout.strip().split("\n")
        except (subprocess.SubprocessError, OSError):
            return False

    def volume_exists(self, volume_name: str) -> bool:
        """Check if a volume exists."""
        try:
            _, stdout, _ = self.run_command(
                ["volume", "ls", "--format", "{{.Name}}"],
                check=False,
            )
            return volume_name in stdout.strip().split("\n")
        except (subprocess.SubprocessError, OSError):
            return False

    def list_containers(self, *, all: bool = True) -> list[str]:
        """List container names.

        Args:
            all: If True, include stopped containers. If False, only running containers.

        Returns:
            List of container names.
        """
        try:
            args = ["ps", "--format", "{{.Names}}"]
            if all:
                args.insert(1, "-a")

            _, stdout, _ = self.run_command(args, check=False)
            containers = [name.strip() for name in stdout.strip().split("\n") if name.strip()]
            return containers
        except (subprocess.SubprocessError, OSError):
            return []

    def list_volumes(self) -> list[str]:
        """List volume names."""
        try:
            _, stdout, _ = self.run_command(
                ["volume", "ls", "--format", "{{.Name}}"],
                check=False,
            )
            volumes = [name.strip() for name in stdout.strip().split("\n") if name.strip()]
            return volumes
        except (subprocess.SubprocessError, OSError):
            return []

    def get_container_status(self, container_name: str) -> str | None:
        """Get the status of a container.

        Returns:
            Container status string (e.g., "running", "exited") or None if not found.
        """
        try:
            _, stdout, _ = self.run_command(
                ["ps", "-a", "--filter", f"name=^{container_name}$", "--format", "{{.Status}}"],
                check=False,
            )
            status = stdout.strip()
            return status or None
        except (subprocess.SubprocessError, OSError):
            return None

    def create_volume(self, volume_name: str) -> None:
        """Create a volume if it doesn't exist."""
        if not self.volume_exists(volume_name):
            self.run_command(["volume", "create", volume_name])

    def remove_volume(self, volume_name: str, *, force: bool = False) -> None:
        """Remove a volume."""
        args = ["volume", "rm"]
        if force:
            args.append("-f")
        args.append(volume_name)
        self.run_command(args, check=False)

    def start_container(self, container_name: str) -> None:
        """Start a stopped container."""
        self.run_command(["start", container_name])

    def stop_container(self, container_name: str, *, timeout: int = 10) -> None:
        """Stop a running container."""
        self.run_command(["stop", "-t", str(timeout), container_name], check=False)

    def remove_container(self, container_name: str, *, force: bool = False) -> None:
        """Remove a container."""
        args = ["rm"]
        if force:
            args.append("-f")
        args.append(container_name)
        self.run_command(args, check=False)

    def get_container_logs(self, container_name: str, *, tail: int | None = None) -> str:
        """Get container logs.

        Args:
            container_name: Name of the container.
            tail: Number of lines from the end to return.

        Returns:
            Container logs as a string.
        """
        args = ["logs"]
        if tail is not None:
            args.extend(["--tail", str(tail)])
        args.append(container_name)

        _, stdout, stderr = self.run_command(args, check=False)
        return stdout + stderr

    def get_container_port(self, container_name: str, container_port: int) -> int | None:
        """Get the host port mapped to a container port.

        Args:
            container_name: Name of the container.
            container_port: The container port to look up.

        Returns:
            The host port number, or None if not found.
        """
        try:
            _, stdout, _ = self.run_command(
                ["port", container_name, f"{container_port}/tcp"],
                check=False,
            )
            # Output format: "0.0.0.0:49153" or ":::49153"
            if stdout.strip():
                port_str = stdout.strip().split(":")[-1]
                return int(port_str)
        except (subprocess.SubprocessError, OSError, ValueError):
            pass
        return None

    def image_exists(self, image: str) -> bool:
        """Check if an image exists locally."""
        try:
            _, stdout, _ = self.run_command(
                ["images", "--format", "{{.Repository}}:{{.Tag}}", image],
                check=False,
            )
            return bool(stdout.strip())
        except (subprocess.SubprocessError, OSError):
            return False

    def pull_image(self, image: str) -> None:
        """Pull an image from a registry."""
        self.run_command(["pull", image], timeout=600)

    def build_image(
        self,
        tag: str,
        *,
        context: Path,
        dockerfile: Path | None = None,
        build_args: dict[str, str] | None = None,
    ) -> None:
        """Build a container image.

        Args:
            tag: Tag for the built image.
            context: Build context directory.
            dockerfile: Path to Dockerfile (relative to context or absolute).
            build_args: Build arguments to pass.
        """
        args = ["build", "-t", tag]

        if dockerfile is not None:
            args.extend(["-f", str(dockerfile)])

        if build_args:
            for key, value in build_args.items():
                args.extend(["--build-arg", f"{key}={value}"])

        args.append(str(context))

        self.run_command(args, timeout=600, cwd=context)
