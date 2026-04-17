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
"""Dependency providers for collection workflows.

This module provides dependency injection utilities for the DMA collector,
including providers for query managers and database drivers.
"""

from __future__ import annotations

from typing import TYPE_CHECKING

from dma.collector.query_managers.base import CanonicalQueryManager
from dma.lib.db.local import get_duckdb_driver

if TYPE_CHECKING:
    from collections.abc import Generator
    from pathlib import Path

    from sqlspec.adapters.duckdb import DuckDBDriver


def provide_canonical_queries(
    driver: "DuckDBDriver | None" = None,
    working_path: Path | None = None,
    export_path: Path | None = None,
) -> Generator[CanonicalQueryManager, None, None]:
    """Provide canonical query manager for DuckDB operations.

    Args:
        driver: Optional existing SQLSpec DuckDB driver.
        working_path: Working directory for temporary files.
        export_path: Export directory for output files.

    Yields:
        CanonicalQueryManager instance.
    """
    if driver:
        yield CanonicalQueryManager(driver=driver)
    else:
        with get_duckdb_driver(working_path=working_path, export_path=export_path) as db_driver:
            yield CanonicalQueryManager(driver=db_driver)
