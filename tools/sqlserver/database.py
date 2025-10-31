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
"""SQL Server database container lifecycle management."""

from __future__ import annotations

import os
import time
from dataclasses import dataclass
from typing import TYPE_CHECKING

from rich.console import Console

if TYPE_CHECKING:
    from tools.lib.container import ContainerRuntime


@dataclass
class DatabaseConfig:
    """Configuration for SQL Server database container."""

    # Container settings
    container_name: str = "cymbal_coffee_sqlserver-db-1"
    image: str = "mcr.microsoft.com/mssql/server:2019-latest"
    hostname: str = "db"

    # Port mapping
    host_port: int = 1433
    container_port: int = 1433

    # Environment variables
    sa_password: str = "super-secret-password-123"
    accept_eula: str = "Y"

    # Volumes
    data_volume_name: str = "sqlserver-db-data"

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
        - DATABASE_PORT (default: 1433)
        - DATABASE_SA_PASSWORD (default: super-secret-password-123)

        Returns:
            DatabaseConfig: Configuration instance
        """
        return cls(
            host_port=int(os.getenv("DATABASE_PORT", "1433")),
            sa_password=os.getenv("DATABASE_SA_PASSWORD", "super-secret-password-123"),
        )


class SQLServerDatabase:
    """Manage SQL Server database container lifecycle."""

    def __init__(
        self,
        runtime: ContainerRuntime,
        config: DatabaseConfig | None = None,
        console: Console | None = None,
    ) -> None:
        """Initialize SQL Server database manager.

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
        """Start SQL Server database container.

        Args:
            pull: Pull latest image before starting
            recreate: Remove and recreate container if exists

        Process:
            1. Check if container already exists
            2. Pull image if requested
            3. Create data volume if needed
            4. Build container run command
            5. Start container
            6. Wait for health check
            7. Display connection info

        Raises:
            ContainerAlreadyRunningError: If container is already running
            ContainerStartError: If container fails to start
        """

        self.console.rule("[bold blue]Starting SQL Server Database Container")

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

        # Create volume if needed
        if not self.runtime.volume_exists(self.config.data_volume_name):
            self.console.print(f"[cyan]Creating volume {self.config.data_volume_name}...[/cyan]")
            self.runtime.run_command(["volume", "create", self.config.data_volume_name])

        # Build run command
        run_args = self._build_run_command()

        # Start container
        self.console.print("[cyan]Starting SQL Server container...[/cyan]")
        self.runtime.run_command(run_args, check=True)

        # Wait for health
        self._wait_for_health()

        # Display connection info
        self._display_connection_info()

    def _build_run_command(self) -> list[str]:
        """Build docker/podman run command arguments.

        Returns:
            list: Command arguments for container run
        """
        return [
            "run",
            "-d",
            "--name",
            self.config.container_name,
            "--hostname",
            self.config.hostname,
            "-p",
            f"{self.config.host_port}:{self.config.container_port}",
            "-e",
            f"ACCEPT_EULA={self.config.accept_eula}",
            "-e",
            f"SA_PASSWORD={self.config.sa_password}",
            "-v",
            f"{self.config.data_volume_name}:/var/opt/mssql",
            "--restart",
            self.config.restart_policy,
            "--log-driver",
            "json-file",
            "--log-opt",
            f"max-size={self.config.log_max_size}",
            "--log-opt",
            f"max-file={self.config.log_max_file}",
            "--health-cmd",
            "/opt/mssql-tools/bin/sqlcmd -S localhost -U sa -P '${SA_PASSWORD}' -Q 'SELECT 1'",
            "--health-interval",
            f"{self.config.health_interval}s",
            "--health-timeout",
            f"{self.config.health_timeout}s",
            "--health-retries",
            str(self.config.health_retries),
            self.config.image,
        ]

    def _pull_image(self) -> None:
        """Pull container image."""
        self.console.print(f"[cyan]Pulling image {self.config.image}...[/cyan]")
        self.runtime.run_command(["pull", self.config.image], check=True)
        self.console.print("[green]✓[/green] Image pulled")

    def _wait_for_health(self) -> None:
        """Wait for container to become healthy."""
        self.console.print("[cyan]Waiting for database to be ready...[/cyan]")

        max_wait = self.config.health_interval * self.config.health_retries
        waited = 0

        while waited < max_wait:
            try:
                status = self.runtime.get_container_status(self.config.container_name)
                if status.get("status") == "running":
                    # Check health
                    _, stdout, _ = self.runtime.run_command(
                        ["inspect", "--format", "{{.State.Health.Status}}", self.config.container_name],
                        check=False,
                    )
                    health_status = stdout.strip()

                    if health_status == "healthy":
                        self.console.print("[green]✓[/green] Database is ready")
                        return
                    if health_status == "unhealthy":
                        msg = "Container became unhealthy"
                        raise ContainerStartError(msg)

            except Exception:  # noqa: S110
                pass

            time.sleep(2)
            waited += 2

        msg = f"Database did not become healthy within {max_wait} seconds"
        raise ContainerStartError(msg)

    def _display_connection_info(self) -> None:
        """Display connection information."""
        self.console.print("\n[bold green]✓ Database Started Successfully[/bold green]")
        self.console.print("\n[bold]Connection Details:[/bold]")
        self.console.print("  Host: [cyan]localhost[/cyan]")
        self.console.print(f"  Port: [cyan]{self.config.host_port}[/cyan]")
        self.console.print("  User: [cyan]sa[/cyan]")
        self.console.print(f"  Password: [cyan]{self.config.sa_password}[/cyan]")

    def stop(self) -> None:
        """Stop the database container."""
        from tools.lib.container import ContainerNotFoundError

        self.console.rule("[bold blue]Stopping SQL Server Database")

        try:
            if not self.runtime.container_running(self.config.container_name):
                self.console.print("[yellow]Container is not running[/yellow]")
                return

            self.console.print(f"[cyan]Stopping {self.config.container_name}...[/cyan]")
            self.runtime.run_command(["stop", self.config.container_name], check=True)
            self.console.print("[green]✓[/green] Container stopped")

        except ContainerNotFoundError:
            self.console.print("[yellow]Container does not exist[/yellow]")

    def restart(self) -> None:
        """Restart the database container."""
        from tools.lib.container import ContainerNotFoundError

        self.console.rule("[bold blue]Restarting SQL Server Database")

        try:
            if not self.runtime.container_exists(self.config.container_name):
                self.console.print("[yellow]Container does not exist. Starting new container...[/yellow]")
                self.start()
                return

            self.console.print(f"[cyan]Restarting {self.config.container_name}...[/cyan]")
            self.runtime.run_command(["restart", self.config.container_name], check=True)
            self.console.print("[green]✓[/green] Container restarted")

        except ContainerNotFoundError:
            self.console.print("[red]Failed to restart container[/red]")
            raise

    def status(self) -> dict[str, str]:
        """Get database container status.

        Returns:
            dict: Container status details
        """
        from tools.lib.container import ContainerNotFoundError

        try:
            return self.runtime.get_container_status(self.config.container_name)
        except ContainerNotFoundError:
            return {"status": "not found", "name": self.config.container_name}

    def logs(self, *, follow: bool = False, tail: int = 50) -> None:
        """Display container logs.

        Args:
            follow: Follow log output
            tail: Number of lines to show from end
        """
        from tools.lib.container import ContainerNotFoundError

        try:
            args = ["logs"]
            if follow:
                args.append("-f")
            args.extend(["--tail", str(tail)])
            args.append(self.config.container_name)

            self.runtime.run_command(args, capture_output=False, check=True)

        except ContainerNotFoundError:
            self.console.print("[red]Container does not exist[/red]")

    def remove(self, *, force: bool = False) -> None:
        """Remove the database container.

        Args:
            force: Force removal even if running
        """
        from tools.lib.container import ContainerNotFoundError

        try:
            if not self.runtime.container_exists(self.config.container_name):
                self.console.print("[yellow]Container does not exist[/yellow]")
                return

            args = ["rm"]
            if force:
                args.append("-f")
            args.append(self.config.container_name)

            self.console.print(f"[cyan]Removing {self.config.container_name}...[/cyan]")
            self.runtime.run_command(args, check=True)
            self.console.print("[green]✓[/green] Container removed")

        except ContainerNotFoundError:
            self.console.print("[yellow]Container does not exist[/yellow]")


class DatabaseError(Exception):
    """Base exception for database errors."""


class ContainerAlreadyRunningError(DatabaseError):
    """Raised when container is already running."""


class ContainerStartError(DatabaseError):
    """Raised when container fails to start."""
