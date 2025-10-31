"""Oracle database container lifecycle management.

This module manages Oracle 23 Free container deployment and operations,
replicating the behavior of docker-compose.yml.
"""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

from rich.console import Console

from tools.lib.container import ContainerNotFoundError, ContainerRuntime


@dataclass
class DatabaseConfig:
    """Configuration for Oracle database container."""

    # Container settings
    container_name: str = "oracle-23free-db"
    image: str = "gvenzl/oracle-free:latest"
    hostname: str = "db"

    # Port mapping
    host_port: int = 1521
    container_port: int = 1521

    # Environment variables (from docker-compose.yml)
    oracle_system_password: str = "super-secret"
    oracle_password: str = "super-secret"
    app_user_password: str = "super-secret"
    app_user: str = "app"

    # Volumes
    data_volume_name: str = "oracle-db-data"

    # Logging
    log_max_size: str = "10m"
    log_max_file: str = "3"

    # Health check
    health_interval: int = 10  # seconds
    health_timeout: int = 5  # seconds
    health_retries: int = 10

    # Restart policy
    restart_policy: str = "unless-stopped"

    @classmethod
    def from_env(cls) -> DatabaseConfig:
        """Create configuration from environment variables.

        Reads from:
        - ORACLE23AI_PORT (default: 1521)
        - ORACLE_SYSTEM_PASSWORD (default: super-secret)
        - ORACLE_PASSWORD (default: super-secret)
        - ORACLE_USER (default: app)

        Returns:
            DatabaseConfig: Configuration instance
        """
        oracle_system_pw = os.getenv("ORACLE_SYSTEM_PASSWORD", "super-secret")
        oracle_user_pw = os.getenv("ORACLE_PASSWORD", "super-secret")

        return cls(
            host_port=int(os.getenv("ORACLE23AI_PORT", "1521")),
            oracle_system_password=oracle_system_pw,
            oracle_password=oracle_system_pw,  # Matches docker-compose behavior
            app_user_password=oracle_user_pw,
            app_user=os.getenv("ORACLE_USER", "app"),
        )


class OracleDatabase:
    """Manage Oracle 23 Free database container lifecycle."""

    def __init__(
        self,
        runtime: ContainerRuntime,
        config: DatabaseConfig | None = None,
        console: Console | None = None,
    ) -> None:
        """Initialize Oracle database manager.

        Args:
            runtime: Container runtime instance
            config: Database configuration (uses defaults if None)
            console: Rich console for output (creates new if None)
        """
        self.runtime = runtime
        self.config = config or DatabaseConfig()
        self.console = console or Console()

    def start(
        self,
        *,
        pull: bool = False,
        recreate: bool = False,
    ) -> None:
        """Start Oracle database container.

        Args:
            pull: Pull latest image before starting
            recreate: Remove and recreate container if exists

        Process:
            1. Check if container already exists
            2. Pull image if requested
            3. Create data volume if needed
            4. Prepare init script mount
            5. Build container run command
            6. Start container
            7. Wait for health check
            8. Display connection info

        Raises:
            ContainerAlreadyRunningError: If container is already running
            ContainerStartError: If container fails to start
        """
        self.console.rule("[bold blue]Starting Oracle Database Container")

        # Check if already running
        if self.runtime.container_running(self.config.container_name):
            if not recreate:
                msg = (
                    f"Container '{self.config.container_name}' is already running. "
                    "Use --recreate to remove and recreate it."
                )
                raise ContainerAlreadyRunningError(msg)
            self.console.print("[yellow]Removing existing container...[/yellow]")
            self.remove(force=True)

        # Check if exists but stopped
        if self.runtime.container_exists(self.config.container_name):
            if recreate:
                self.console.print("[yellow]Removing existing container...[/yellow]")
                self.remove()
            else:
                self.console.print("[cyan]Starting existing container...[/cyan]")
                self.runtime.run_command(["start", self.config.container_name])
                self.console.print("[green]✓[/green] Container started")
                return

        # Pull image if requested
        if pull:
            self._pull_image()

        # Create volume
        self._create_volume(self.config.data_volume_name)

        # Build run command
        run_cmd = self._build_run_command()

        # Start container
        self.console.print("[cyan]Creating and starting container...[/cyan]")
        try:
            _, stdout, _stderr = self.runtime.run_command(run_cmd)
            container_id = stdout.strip()[:12]
            self.console.print(f"[green]✓[/green] Container created: [dim]{container_id}[/dim]")
        except Exception as e:
            msg = f"Failed to start container: {e}"
            raise ContainerStartError(msg) from e

        # Wait for healthy
        self.console.print("[cyan]Waiting for database to become healthy...[/cyan]")
        if self.wait_for_healthy(timeout=300):
            self.console.print("[green]✓[/green] Database is healthy and ready!")
            info = self.get_connection_info()
            self.console.print("\n[bold]Connection Info:[/bold]")
            self.console.print(f"  Host: {info['host']}")
            self.console.print(f"  Port: {info['port']}")
            self.console.print(f"  Service: {info['service_name']}")
            self.console.print(f"  User: {info['user']}")
            self.console.print(f"  DSN: {info['dsn']}")
        else:
            self.console.print("[yellow]⚠[/yellow] Container started but health check timed out")
            self.console.print(
                f"  Check logs with: {self.runtime.get_runtime_command()} logs {self.config.container_name}"
            )

    def stop(self, *, timeout: int = 30) -> None:
        """Stop Oracle database container.

        Args:
            timeout: Seconds to wait before forcing stop

        Raises:
            ContainerNotFoundError: If container doesn't exist
        """
        if not self.runtime.container_exists(self.config.container_name):
            msg = f"Container '{self.config.container_name}' does not exist"
            raise ContainerNotFoundError(msg)

        self.console.print("[cyan]Stopping container...[/cyan]")
        self.runtime.run_command(["stop", "-t", str(timeout), self.config.container_name])
        self.console.print("[green]✓[/green] Container stopped")

    def restart(self, *, timeout: int = 30) -> None:
        """Restart Oracle database container.

        Args:
            timeout: Seconds to wait for stop before forcing

        Raises:
            ContainerNotFoundError: If container doesn't exist
        """
        if not self.runtime.container_exists(self.config.container_name):
            msg = f"Container '{self.config.container_name}' does not exist"
            raise ContainerNotFoundError(msg)

        self.console.print("[cyan]Restarting container...[/cyan]")
        self.runtime.run_command(["restart", "-t", str(timeout), self.config.container_name])
        self.console.print("[green]✓[/green] Container restarted")

    def remove(
        self,
        *,
        volumes: bool = False,
        force: bool = False,
    ) -> None:
        """Remove Oracle database container.

        Args:
            volumes: Also remove associated volumes
            force: Force removal even if running

        Raises:
            ContainerNotFoundError: If container doesn't exist
        """
        if not self.runtime.container_exists(self.config.container_name):
            msg = f"Container '{self.config.container_name}' does not exist"
            raise ContainerNotFoundError(msg)

        remove_cmd = ["rm"]
        if force:
            remove_cmd.append("-f")
        remove_cmd.append(self.config.container_name)

        self.console.print("[cyan]Removing container...[/cyan]")
        self.runtime.run_command(remove_cmd)
        self.console.print("[green]✓[/green] Container removed")

        if volumes and self.runtime.volume_exists(self.config.data_volume_name):
            self.console.print("[cyan]Removing volume...[/cyan]")
            self.runtime.run_command(["volume", "rm", self.config.data_volume_name])
            self.console.print("[green]✓[/green] Volume removed")

    def logs(
        self,
        *,
        follow: bool = False,
        tail: int | None = None,
        since: str | None = None,
    ) -> None:
        """Stream container logs.

        Args:
            follow: Continue streaming new logs
            tail: Number of lines from end to show
            since: Show logs since timestamp/duration

        Raises:
            ContainerNotFoundError: If container doesn't exist
        """
        if not self.runtime.container_exists(self.config.container_name):
            msg = f"Container '{self.config.container_name}' does not exist"
            raise ContainerNotFoundError(msg)

        logs_cmd = ["logs"]
        if follow:
            logs_cmd.append("-f")
        if tail:
            logs_cmd.extend(["--tail", str(tail)])
        if since:
            logs_cmd.extend(["--since", since])
        logs_cmd.append(self.config.container_name)

        # Stream logs directly (don't capture)
        self.runtime.run_command(logs_cmd, capture_output=False)

    def status(self) -> ContainerStatus:
        """Get detailed container status.

        Returns:
            ContainerStatus: Current status information

        Raises:
            ContainerNotFoundError: If container doesn't exist
        """
        exists = self.runtime.container_exists(self.config.container_name)
        if not exists:
            return ContainerStatus(
                exists=False,
                running=False,
                healthy=None,
                status="not found",
                container_id=None,
                uptime=None,
                ports={},
                image=self.config.image,
                created_at=None,
            )

        # Get status from runtime
        status_dict = self.runtime.get_container_status(self.config.container_name)
        running = self.runtime.container_running(self.config.container_name)
        healthy = self.is_healthy() if running else None

        return ContainerStatus(
            exists=True,
            running=running,
            healthy=healthy,
            status=status_dict.get("status", "unknown"),
            container_id=status_dict.get("id"),
            uptime=None,  # Could parse from created_at if needed
            ports={"1521": str(self.config.host_port)},
            image=status_dict.get("image", self.config.image),
            created_at=status_dict.get("created"),
        )

    def is_running(self) -> bool:
        """Quick check if container is running.

        Returns:
            bool: True if container exists and is running
        """
        return self.runtime.container_running(self.config.container_name)

    def is_healthy(self) -> bool:
        """Check if container health check is passing.

        Returns:
            bool: True if container is healthy

        Note:
            Returns False if container doesn't exist or isn't running
        """
        if not self.is_running():
            return False

        try:
            _, stdout, _ = self.runtime.run_command(
                ["inspect", "--format", "{{.State.Health.Status}}", self.config.container_name],
                check=False,
            )
            health_status = stdout.strip()
        except Exception:  # noqa: BLE001
            return False
        else:
            return health_status == "healthy"

    def wait_for_healthy(
        self,
        timeout: int = 300,
        *,
        show_progress: bool = True,
    ) -> bool:
        """Wait for container to become healthy.

        Args:
            timeout: Maximum seconds to wait
            show_progress: Show progress indicator

        Returns:
            bool: True if became healthy, False if timeout

        Used after starting container to ensure it's ready.
        """
        start_time = time.time()

        if show_progress:
            with self.console.status("[bold yellow]Waiting for database to be healthy...") as status:
                while time.time() - start_time < timeout:
                    if self.is_healthy():
                        return True

                    elapsed = int(time.time() - start_time)
                    status.update(f"[bold yellow]Waiting for database... ({elapsed}s / {timeout}s)")
                    time.sleep(5)
        else:
            while time.time() - start_time < timeout:
                if self.is_healthy():
                    return True
                time.sleep(5)

        return False

    def get_connection_info(self) -> dict[str, Any]:
        """Get connection information for the database.

        Returns:
            dict: Connection details including:
                - host: Database host
                - port: Database port
                - service_name: Oracle service name
                - user: App user name
                - password: App user password
                - dsn: Connection DSN string
        """
        return {
            "host": "localhost",
            "port": self.config.host_port,
            "service_name": "FREEPDB1",
            "user": self.config.app_user,
            "password": self.config.app_user_password,
            "dsn": f"localhost:{self.config.host_port}/FREEPDB1",
        }

    def exec_sql(self, sql: str, *, user: str = "app") -> str:
        """Execute SQL command in running container.

        Args:
            sql: SQL command to execute
            user: Database user to connect as

        Returns:
            str: Command output

        Raises:
            ContainerNotFoundError: If container doesn't exist
            DatabaseNotReadyError: If database isn't healthy
        """
        if not self.is_running():
            msg = f"Container '{self.config.container_name}' is not running"
            raise ContainerNotFoundError(msg)

        if not self.is_healthy():
            msg = "Database is not healthy yet"
            raise DatabaseNotReadyError(msg)

        # Execute SQL via sqlplus in container
        _, stdout, _ = self.runtime.run_command([
            "exec",
            self.config.container_name,
            "sqlplus",
            "-S",
            f"{user}/{self.config.app_user_password}@FREEPDB1",
            sql,
        ])

        return stdout

    def _build_run_command(self) -> list[str]:
        """Build the container run command.

        Returns:
            list[str]: Command arguments for container run

        Constructs command matching docker-compose.yml:
        - Port mapping
        - Environment variables
        - Volume mounts
        - Health check
        - Restart policy
        - Logging options
        """
        cmd = [
            "run",
            "-d",  # Detached
            "--name",
            self.config.container_name,
            "--hostname",
            self.config.hostname,
            # Port mapping
            "-p",
            f"{self.config.host_port}:{self.config.container_port}",
            # Environment variables
            "-e",
            f"ORACLE_SYSTEM_PASSWORD={self.config.oracle_system_password}",
            "-e",
            f"ORACLE_PASSWORD={self.config.oracle_password}",
            "-e",
            f"APP_USER_PASSWORD={self.config.app_user_password}",
            "-e",
            f"APP_USER={self.config.app_user}",
            # Data volume
            "-v",
            f"{self.config.data_volume_name}:/opt/oracle/oradata",
            # Restart policy
            "--restart",
            self.config.restart_policy,
            # Logging
            "--log-opt",
            f"max-size={self.config.log_max_size}",
            "--log-opt",
            f"max-file={self.config.log_max_file}",
            # Health check
            "--health-cmd",
            "healthcheck.sh",
            "--health-interval",
            f"{self.config.health_interval}s",
            "--health-timeout",
            f"{self.config.health_timeout}s",
            "--health-retries",
            str(self.config.health_retries),
        ]

        # Mount individual files from on_init folder (run once during first DB creation)
        # Mounted to /container-entrypoint-initdb.d (gvenzl/oracle-free standard)
        project_root = Path(__file__).parent.parent.parent
        on_init_dir = project_root / "tools" / "oracle" / "on_init"
        if on_init_dir.exists():
            for script_file in sorted(on_init_dir.glob("*.sql")) + sorted(on_init_dir.glob("*.sh")):
                if script_file.is_file() and script_file.name != ".gitkeep":
                    # Use :z for SELinux compatibility (works with both Docker and Podman)
                    cmd.extend([
                        "-v",
                        f"{script_file.absolute()}:/container-entrypoint-initdb.d/{script_file.name}:z",
                    ])

        # Mount individual files from on_startup folder (run every time container starts)
        # Mounted to /container-entrypoint-startdb.d (gvenzl/oracle-free standard)
        on_startup_dir = project_root / "tools" / "oracle" / "on_startup"
        if on_startup_dir.exists():
            for script_file in sorted(on_startup_dir.glob("*.sql")) + sorted(on_startup_dir.glob("*.sh")):
                if script_file.is_file() and script_file.name != ".gitkeep":
                    # Use :z for SELinux compatibility (works with both Docker and Podman)
                    cmd.extend([
                        "-v",
                        f"{script_file.absolute()}:/container-entrypoint-startdb.d/{script_file.name}:z",
                    ])

        # Image name
        cmd.append(self.config.image)

        return cmd

    def _create_volume(self, volume_name: str) -> None:
        """Create named volume if it doesn't exist.

        Args:
            volume_name: Name of volume to create
        """
        if not self.runtime.volume_exists(volume_name):
            self.console.print(f"Creating volume [cyan]{volume_name}[/cyan]...")
            self.runtime.run_command(["volume", "create", volume_name])

    def _pull_image(self) -> None:
        """Pull the Oracle database image."""
        self.console.print(f"Pulling image [cyan]{self.config.image}[/cyan]...")
        with self.console.status("[bold yellow]Pulling image..."):
            self.runtime.run_command(["pull", self.config.image])


@dataclass
class ContainerStatus:
    """Container status information."""

    exists: bool
    running: bool
    healthy: bool | None
    status: str  # e.g., "running", "exited", "created"
    container_id: str | None
    uptime: str | None
    ports: dict[str, str]  # Container port -> host port mapping
    image: str
    created_at: str | None


class DatabaseError(Exception):
    """Base exception for database operations."""


class ContainerAlreadyRunningError(DatabaseError):
    """Raised when trying to start an already running container."""


class ContainerStartError(DatabaseError):
    """Raised when container fails to start."""


class DatabaseNotReadyError(DatabaseError):
    """Raised when database isn't ready for operations."""
