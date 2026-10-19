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
"""SQL Server database container management."""

from __future__ import annotations

import subprocess
from dataclasses import dataclass

from tools.lib.database import (
    BaseDatabaseConfig,
    ContainerAlreadyRunningError,
    ContainerStartError,
    DatabaseContainer,
    DatabaseError,
)

__all__ = [
    "ContainerAlreadyRunningError",
    "ContainerStartError",
    "DatabaseConfig",
    "DatabaseError",
    "SQLServerDatabase",
]


@dataclass
class DatabaseConfig(BaseDatabaseConfig):
    """Configuration for a SQL Server database container.

    Attributes:
        sa_password: Password for the SA user. Must meet SQL Server complexity requirements.
        accept_eula: Accept the SQL Server EULA.
        mssql_pid: SQL Server product ID (Developer, Express, etc.).
    """

    container_name: str = "dma-test-mssql"
    image: str = "mcr.microsoft.com/mssql/server:2022-latest"
    container_port: int = 1433
    sa_password: str = "Super-secret1"
    accept_eula: str = "Y"
    mssql_pid: str = "Developer"
    data_volume_name: str = "dma-test-mssql-data"
    health_retries: int = 20


class SQLServerDatabase(DatabaseContainer[DatabaseConfig]):
    """Manages a SQL Server database container."""

    default_config_factory = DatabaseConfig
    run_timeout_seconds = 120
    health_poll_interval_seconds = 3
    stop_timeout_seconds = 15

    def is_healthy(self) -> bool:
        """Check if the database is healthy and accepting connections."""
        try:
            returncode, _, _ = self.runtime.run_command(
                [
                    "exec",
                    self.config.container_name,
                    "/opt/mssql-tools18/bin/sqlcmd",
                    "-S",
                    "localhost",
                    "-U",
                    "sa",
                    "-P",
                    self.config.sa_password,
                    "-Q",
                    "SELECT 1",
                    "-C",
                    "-b",
                ],
                check=False,
            )
        except (subprocess.SubprocessError, OSError):
            return False
        return returncode == 0

    def _build_run_args(self) -> list[str]:
        """Build the container run command arguments for SQL Server."""
        config = self.config
        health_cmd = f"/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P '{config.sa_password}' -Q 'SELECT 1' -C -b"
        return self._append_common_run_args(
            volume_mount=f"{config.data_volume_name}:/var/opt/mssql",
            env_vars=[
                f"SA_PASSWORD={config.sa_password}",
                f"ACCEPT_EULA={config.accept_eula}",
                f"MSSQL_PID={config.mssql_pid}",
                f"MSSQL_TCP_PORT={config.container_port}",
            ],
            health_cmd=health_cmd,
        )
