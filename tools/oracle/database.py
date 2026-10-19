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
    "OracleDatabase",
]


@dataclass
class DatabaseConfig(BaseDatabaseConfig):
    """Configuration for an Oracle database container.

    Attributes:
        oracle_password: Password for SYS, SYSTEM, and PDBADMIN users.
        app_user: Application user name.
        app_user_password: Password for the application user.
    """

    container_name: str = "dma-test-oracle"
    image: str = "gvenzl/oracle-free:23-slim-faststart"
    container_port: int = 1521
    oracle_password: str = "super-secret"
    app_user: str = "app"
    app_user_password: str = "super-secret"
    data_volume_name: str = "dma-test-oracle-data"
    health_interval: int = 15
    health_timeout: int = 10
    health_retries: int = 30


class OracleDatabase(DatabaseContainer[DatabaseConfig]):
    """Manages an Oracle database container."""

    default_config_factory = DatabaseConfig
    run_timeout_seconds = 120
    health_poll_interval_seconds = 5
    stop_timeout_seconds = 30
    failure_log_tail_lines = 100

    def is_healthy(self) -> bool:
        """Check if the database is healthy and accepting connections."""
        try:
            returncode, _, _ = self.runtime.run_command(
                ["exec", self.config.container_name, "healthcheck.sh"],
                check=False,
            )
        except (subprocess.SubprocessError, OSError):
            return False
        return returncode == 0

    def _build_run_args(self) -> list[str]:
        """Build the container run command arguments for Oracle."""
        config = self.config
        return self._append_common_run_args(
            volume_mount=f"{config.data_volume_name}:/opt/oracle/oradata",
            env_vars=[
                f"ORACLE_PASSWORD={config.oracle_password}",
                f"APP_USER={config.app_user}",
                f"APP_USER_PASSWORD={config.app_user_password}",
            ],
            health_cmd="healthcheck.sh",
        )
