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
    "PostgreSQLDatabase",
]


@dataclass
class DatabaseConfig(BaseDatabaseConfig):
    """Configuration for a PostgreSQL database container.

    Attributes:
        postgres_password: Password for the postgres user.
        postgres_user: Username for the primary user.
        postgres_db: Name of the default database.
        data_mount_path: Mount path inside the container (use "/var/lib/postgresql" for PG 18+).
    """

    container_name: str = "dma-test-postgres"
    image: str = "postgres:latest"
    container_port: int = 5432
    postgres_password: str = "super-secret"
    postgres_user: str = "postgres"
    postgres_db: str = "postgres"
    data_volume_name: str = "dma-test-postgres-data"
    data_mount_path: str = "/var/lib/postgresql/data"


class PostgreSQLDatabase(DatabaseContainer[DatabaseConfig]):
    """Manages a PostgreSQL database container."""

    default_config_factory = DatabaseConfig
    run_timeout_seconds = 60
    health_poll_interval_seconds = 2
    stop_timeout_seconds = 10

    def is_healthy(self) -> bool:
        """Check if the database is healthy and accepting TCP connections."""
        try:
            _, stdout, _ = self.runtime.run_command(
                [
                    "exec",
                    self.config.container_name,
                    "pg_isready",
                    "-h",
                    "127.0.0.1",
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

    def _build_run_args(self) -> list[str]:
        """Build the container run command arguments for PostgreSQL."""
        config = self.config
        return self._append_common_run_args(
            volume_mount=f"{config.data_volume_name}:{config.data_mount_path}",
            env_vars=[
                f"POSTGRES_PASSWORD={config.postgres_password}",
                f"POSTGRES_USER={config.postgres_user}",
                f"POSTGRES_DB={config.postgres_db}",
            ],
            health_cmd=f"pg_isready -h 127.0.0.1 -U {config.postgres_user} -d {config.postgres_db}",
        )
