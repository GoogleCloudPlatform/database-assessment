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
"""Database connectivity layer using SQLSpec.

This module provides the database abstraction layer for DMA Collector using
SQLSpec for unified database access. Key components:

- config: Configuration factories for database connections
- manager: Global SQLSpec instance and query management
- local: DuckDB connection management for local analysis
"""

from __future__ import annotations

from dma.lib.db.config import (
    SourceInfo,
    create_duckdb_config,
    create_postgres_adbc_config,
)
from dma.lib.db.local import get_duckdb_driver
from dma.lib.db.manager import (
    get_available_queries,
    get_sql,
    get_sqlspec,
    reset_sqlspec,
)

__all__ = (
    "SourceInfo",
    "create_duckdb_config",
    "create_postgres_adbc_config",
    "get_available_queries",
    "get_duckdb_driver",
    "get_sql",
    "get_sqlspec",
    "reset_sqlspec",
)
