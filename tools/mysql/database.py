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
"""MySQL database container management."""

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
    "MySQLDatabase",
]


@dataclass
class DatabaseConfig(BaseDatabaseConfig):
    """Configuration for a MySQL database container.

    Attributes:
        mysql_root_password: Password for the root user.
        mysql_user: Username for the application user.
        mysql_password: Password for the application user.
        mysql_database: Name of the default database.
    """

    container_name: str = "dma-test-mysql"
    image: str = "mysql:8.0"
    container_port: int = 3306
    mysql_root_password: str = "super-secret"
    mysql_user: str = "app"
    mysql_password: str = "super-secret"
    mysql_database: str = "db"
    data_volume_name: str = "dma-test-mysql-data"
    health_retries: int = 15


class MySQLDatabase(DatabaseContainer[DatabaseConfig]):
    """Manages a MySQL database container."""

    default_config_factory = DatabaseConfig
    run_timeout_seconds = 60
    health_poll_interval_seconds = 2
    stop_timeout_seconds = 10

    def is_healthy(self) -> bool:
        """Check if the database is healthy and accepting TCP connections."""
        try:
            returncode, _, _ = self.runtime.run_command(
                [
                    "exec",
                    self.config.container_name,
                    "mysqladmin",
                    "ping",
                    "-h",
                    "127.0.0.1",
                    "--protocol=TCP",
                    "-u",
                    "root",
                    f"-p{self.config.mysql_root_password}",
                ],
                check=False,
            )
        except (subprocess.SubprocessError, OSError):
            return False
        return returncode == 0

    def _build_run_args(self) -> list[str]:
        """Build the container run command arguments for MySQL."""
        config = self.config
        return self._append_common_run_args(
            volume_mount=f"{config.data_volume_name}:/var/lib/mysql",
            env_vars=[
                f"MYSQL_ROOT_PASSWORD={config.mysql_root_password}",
                f"MYSQL_USER={config.mysql_user}",
                f"MYSQL_PASSWORD={config.mysql_password}",
                f"MYSQL_DATABASE={config.mysql_database}",
                "MYSQL_ROOT_HOST=%",
                "LANG=C.UTF-8",
            ],
            health_cmd="mysqladmin ping -h 127.0.0.1 --protocol=TCP",
        )
