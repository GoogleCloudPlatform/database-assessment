# Copyright 2024 Google LLC

# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at

#     https://www.apache.org/licenses/LICENSE-2.0

# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
"""SQLSpec configuration factories for database connections.

This module provides factory functions for creating SQLSpec configuration
objects from DMA connection parameters. These configurations are used by
the SQLSpec manager to establish database connections.
"""

from __future__ import annotations

import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import TYPE_CHECKING

from sqlspec.adapters.adbc import AdbcConfig
from sqlspec.adapters.duckdb import DuckDBConfig

if TYPE_CHECKING:
    from dma.types import SupportedSources


@dataclass
class SourceInfo:
    """Connection information for a source database.

    Attributes:
        db_type: The type of database (POSTGRES, MYSQL, ORACLE, MSSQL).
        username: Database authentication username.
        password: Database authentication password.
        hostname: Database server hostname or IP address.
        port: Database server port number.
    """

    db_type: SupportedSources
    username: str
    password: str
    hostname: str
    port: int


def create_postgres_adbc_config(
    src_info: SourceInfo,
    database: str,
) -> AdbcConfig:
    """Create ADBC configuration for PostgreSQL connection.

    Uses ADBC driver for zero-copy Arrow data transfer, providing
    5-10x performance improvement for large result sets.

    Args:
        src_info: Source connection information.
        database: Target database name.

    Returns:
        Configured AdbcConfig instance.
    """
    uri = f"postgresql://{src_info.username}:{src_info.password}@{src_info.hostname}:{src_info.port}/{database}"
    return AdbcConfig(
        connection_config={"uri": uri},
    )


def create_duckdb_config(
    working_path: Path | None = None,
    export_path: Path | None = None,
    database: str | None = None,
    memory_limit: str = "1GB",
    worker_threads: int = 2,
) -> DuckDBConfig:
    """Create DuckDB configuration for local analysis database.

    Args:
        working_path: Directory for temporary files. Defaults to system temp.
        export_path: If provided, creates persistent database at this location.
        database: Explicit database path. Takes precedence over export_path.
        memory_limit: Maximum memory usage (e.g., "1GB", "2GB").
        worker_threads: Number of worker threads for parallel operations.

    Returns:
        Configured DuckDBConfig instance.
    """
    if database is None and export_path is not None:
        database = str(Path(export_path / "assessment.db").absolute())
    elif database is None:
        database = ":memory:"

    if working_path is None:
        working_path = Path(tempfile.gettempdir())

    Path(working_path).mkdir(parents=True, exist_ok=True)

    return DuckDBConfig(
        connection_config={
            "database": database,
            "read_only": False,
            "memory_limit": memory_limit,
            "temp_directory": str(working_path),
            "threads": worker_threads,
            "preserve_insertion_order": False,
        },
    )
