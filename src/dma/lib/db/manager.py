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
"""SQLSpec manager for centralized database and query management.

This module provides a singleton SQLSpec instance that serves as the central
coordinator for all database operations in the DMA Collector. It handles:

1. Loading SQL files from the collector/sql directory tree
2. Providing access to named queries via get_sql()
3. Managing database configuration registration

SQL files use the `-- name: query-name` comment format (kebab-case names).
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING

from sqlspec import SQLSpec

if TYPE_CHECKING:
    from sqlspec.statement.sql import SQL

from dma.utils import module_to_os_path

_root_path = module_to_os_path("dma")


@lru_cache(maxsize=1)
def get_sqlspec() -> SQLSpec:
    """Get or create the global SQLSpec manager.

    The manager is created lazily on first access and loads SQL files from:
    - collector/sql/sources/postgres/ - PostgreSQL-specific collection queries
    - collector/sql/canonical/ - DuckDB analysis queries

    Returns:
        The global SQLSpec instance with all SQL files loaded.
    """
    sqlspec = SQLSpec()
    sql_root = Path(_root_path) / "collector" / "sql"

    # Load source database queries (currently only PostgreSQL is supported)
    postgres_path = sql_root / "sources" / "postgres"
    if postgres_path.exists():
        sqlspec.load_sql_files(postgres_path)

    # Load canonical DuckDB queries
    canonical_path = sql_root / "canonical"
    if canonical_path.exists():
        sqlspec.load_sql_files(canonical_path)

    return sqlspec


def reset_sqlspec() -> None:
    """Reset the global SQLSpec manager.

    This is primarily useful for testing to ensure a clean state.
    """
    get_sqlspec.cache_clear()


def get_sql(name: str) -> "SQL":
    """Get a named SQL query from the manager.

    This is a convenience function that delegates to the global SQLSpec
    instance's get_sql method.

    Args:
        name: The query name as defined by '-- name:' comment in SQL files.

    Returns:
        The SQL statement object.

    Raises:
        KeyError: If the query name is not found.
    """
    return get_sqlspec().get_sql(name)


def list_queries() -> list[str]:
    """List all available query names.

    Returns:
        List of all query names loaded from SQL files.
    """
    return list(get_sqlspec().list_sql_queries())


def get_available_queries(prefix: str | None = None) -> list[str]:
    """Get list of available query names, optionally filtered by prefix.

    Args:
        prefix: If provided, only return queries starting with this prefix.

    Returns:
        Sorted list of query names.
    """
    all_queries = list_queries()

    if prefix is None:
        return sorted(all_queries)
    return sorted(q for q in all_queries if q.startswith(prefix))
