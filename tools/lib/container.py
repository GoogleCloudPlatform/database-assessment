"""Container runtime abstraction for Docker and Podman.

This module provides a unified interface for container operations,
automatically detecting and working with either Docker or Podman.
"""

from __future__ import annotations

import shutil
import subprocess  # noqa: S404
from enum import Enum


class RuntimeType(str, Enum):
    """Container runtime types."""

    DOCKER = "docker"
    PODMAN = "podman"
    NONE = "none"


class ContainerRuntime:
    """Unified interface for Docker and Podman container operations."""

    def __init__(self) -> None:
        """Initialize container runtime by auto-detecting available runtime."""
        self._runtime_type = self.detect_runtime()
        self._command = self._runtime_type.value if self._runtime_type != RuntimeType.NONE else None

    @staticmethod
    def detect_runtime() -> RuntimeType:
        """Detect which container runtime is available.

        Returns:
            RuntimeType: DOCKER, PODMAN, or NONE

        Checks:
            1. Look for 'docker' command
            2. Look for 'podman' command
            3. Verify command is executable and responsive
        """
        # Check for Docker first (prefer Docker if both are available)
        if shutil.which("docker"):
            try:
                result = subprocess.run(
                    ["docker", "--version"],
                    capture_output=True,
                    timeout=5,
                    check=False,
                )
                if result.returncode == 0:
                    return RuntimeType.DOCKER
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

        # Check for Podman
        if shutil.which("podman"):
            try:
                result = subprocess.run(
                    ["podman", "--version"],
                    capture_output=True,
                    timeout=5,
                    check=False,
                )
                if result.returncode == 0:
                    return RuntimeType.PODMAN
            except (subprocess.TimeoutExpired, FileNotFoundError):
                pass

        return RuntimeType.NONE

    def is_available(self) -> bool:
        """Check if any container runtime is available.

        Returns:
            bool: True if Docker or Podman is available
        """
        return self._runtime_type != RuntimeType.NONE

    def get_runtime_type(self) -> RuntimeType:
        """Get the detected runtime type.

        Returns:
            RuntimeType: The container runtime being used
        """
        return self._runtime_type

    def get_runtime_command(self) -> str:
        """Get the base command for the runtime.

        Returns:
            str: 'docker' or 'podman'

        Raises:
            NoRuntimeAvailableError: If no runtime is available
        """
        if not self.is_available():
            raise NoRuntimeAvailableError(
                "No container runtime available. Please install Docker or Podman.\n"
                "Docker: https://docs.docker.com/get-docker/\n"
                "Podman: https://podman.io/getting-started/installation"
            )
        return self._command  # type: ignore[return-value]

    def run_command(
        self,
        args: list[str],
        *,
        capture_output: bool = True,
        check: bool = True,
        timeout: int | None = None,
    ) -> tuple[int, str, str]:
        """Run a container runtime command.

        Args:
            args: Command arguments (e.g., ['ps', '-a'])
            capture_output: Whether to capture stdout/stderr
            check: Whether to raise on non-zero exit
            timeout: Command timeout in seconds

        Returns:
            tuple: (return_code, stdout, stderr)

        Raises:
            NoRuntimeAvailableError: If no runtime is available
            subprocess.CalledProcessError: If check=True and command fails
            subprocess.TimeoutExpired: If timeout is exceeded
        """
        cmd = self.get_runtime_command()
        full_cmd = [cmd, *args]

        result = subprocess.run(
            full_cmd,
            capture_output=capture_output,
            timeout=timeout,
            check=check,
            text=True,
        )

        stdout = result.stdout if capture_output else ""
        stderr = result.stderr if capture_output else ""

        return result.returncode, stdout, stderr

    def version(self) -> str:
        """Get container runtime version.

        Returns:
            str: Version string
        """
        _, stdout, _ = self.run_command(["--version"])
        return stdout.strip()

    def container_exists(self, container_name: str) -> bool:
        """Check if a container exists.

        Args:
            container_name: Name of the container

        Returns:
            bool: True if container exists
        """
        try:
            returncode, _, _ = self.run_command(
                ["ps", "-a", "--filter", f"name=^{container_name}$", "--format", "{{.Names}}"],
                check=False,
            )
            if returncode != 0:
                return False

            # Check if any output (container exists)
            _, stdout, _ = self.run_command(
                ["ps", "-a", "--filter", f"name=^{container_name}$", "--format", "{{.Names}}"],
                check=False,
            )
            return container_name in stdout.strip()
        except (subprocess.CalledProcessError, NoRuntimeAvailableError):
            return False

    def container_running(self, container_name: str) -> bool:
        """Check if a container is running.

        Args:
            container_name: Name of the container

        Returns:
            bool: True if container is running
        """
        try:
            _, stdout, _ = self.run_command(
                ["ps", "--filter", f"name=^{container_name}$", "--format", "{{.Names}}"],
                check=False,
            )
            return container_name in stdout.strip()
        except (subprocess.CalledProcessError, NoRuntimeAvailableError):
            return False

    def get_container_status(self, container_name: str) -> dict[str, str]:
        """Get detailed container status.

        Args:
            container_name: Name of the container

        Returns:
            dict: Container status details including:
                - name: Container name
                - status: running, stopped, etc.
                - id: Container ID
                - image: Image name
                - ports: Port mappings
                - created: Creation timestamp

        Raises:
            ContainerNotFoundError: If container doesn't exist
        """
        if not self.container_exists(container_name):
            raise ContainerNotFoundError(f"Container '{container_name}' does not exist")

        # Get container details using inspect
        _, stdout, _ = self.run_command([
            "inspect",
            "--format",
            "{{.Name}}|{{.State.Status}}|{{.Id}}|{{.Config.Image}}|{{.Created}}",
            container_name,
        ])

        min_parts_for_status = 2
        min_parts_for_id = 3
        min_parts_for_image = 4
        min_parts_for_created = 5
        short_id_length = 12

        parts = stdout.strip().split("|")
        status_dict = {
            "name": parts[0].lstrip("/") if parts[0] else container_name,
            "status": parts[1] if len(parts) > min_parts_for_status - 1 else "unknown",
            "id": parts[2][:short_id_length] if len(parts) > min_parts_for_id - 1 else "",  # Short ID
            "image": parts[3] if len(parts) > min_parts_for_image - 1 else "",
            "created": parts[4] if len(parts) > min_parts_for_created - 1 else "",
        }

        # Get port mappings
        _, ports_output, _ = self.run_command(
            ["port", container_name],
            check=False,
        )
        status_dict["ports"] = ports_output.strip() if ports_output else "none"

        return status_dict

    def list_containers(self, all: bool = True) -> list[str]:
        """List all containers.

        Args:
            all: Whether to list all containers (including stopped)

        Returns:
            list[str]: List of container names
        """
        args = ["ps", "--format", "{{.Names}}"]
        if all:
            args.append("-a")
        _, stdout, _ = self.run_command(args)
        return stdout.strip().split("\n") if stdout else []

    def volume_exists(self, volume_name: str) -> bool:
        """Check if a volume exists.

        Args:
            volume_name: Name of the volume

        Returns:
            bool: True if volume exists
        """
        try:
            _, stdout, _ = self.run_command(
                ["volume", "ls", "--filter", f"name=^{volume_name}$", "--format", "{{.Name}}"],
                check=False,
            )
            return volume_name in stdout.strip()
        except (subprocess.CalledProcessError, NoRuntimeAvailableError):
            return False


class ContainerRuntimeError(Exception):
    """Base exception for container runtime errors."""


class NoRuntimeAvailableError(ContainerRuntimeError):
    """Raised when no container runtime is detected."""


class ContainerNotFoundError(ContainerRuntimeError):
    """Raised when specified container doesn't exist."""
