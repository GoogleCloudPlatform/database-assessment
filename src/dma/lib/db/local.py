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
"""DuckDB local database management using SQLSpec.

This module provides DuckDB connection management for the local analysis
database using SQLSpec's DuckDBConfig for Arrow-native data transfer.
"""

from __future__ import annotations

from contextlib import contextmanager
from typing import TYPE_CHECKING

from dma.lib.db.config import create_duckdb_config

if TYPE_CHECKING:
    from collections.abc import Iterator
    from pathlib import Path

    from sqlspec.adapters.duckdb import DuckDBDriver


@contextmanager
def get_duckdb_driver(
    working_path: Path | None = None,
    export_path: Path | None = None,
    database: str | None = None,
) -> Iterator[DuckDBDriver]:
    """Yield a SQLSpec DuckDB driver for Arrow-native data operations.

    Args:
        working_path: Directory for temporary files.
        export_path: If provided, creates persistent database.
        database: Explicit database path.

    Yields:
        SQLSpec DuckDB driver with Arrow support via to_arrow().
    """
    config = create_duckdb_config(
        working_path=working_path,
        export_path=export_path,
        database=database,
    )
    with config.provide_session() as driver:
        yield driver
