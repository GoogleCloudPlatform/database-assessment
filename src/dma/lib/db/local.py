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
from __future__ import annotations

import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING

import duckdb

if TYPE_CHECKING:
    from collections.abc import Iterator


@contextmanager
def get_duckdb_connection(
    working_path: Path | None = None, export_path: Path | None = None, database: str | None = None
) -> Iterator[duckdb.DuckDBPyConnection]:
    """Yield a new duckdb connections and automatically manages resource cleanup."""

    if database is None and export_path is not None:
        database = f"{Path(export_path / 'assessment.db').absolute()!s}"
    elif database is None:
        database = ":memory:"
    if working_path is None:
        working_path = Path(tempfile.gettempdir())
    config = {
        "memory_limit": "1GB",
        "temp_directory": str(working_path),
        "worker_threads": 2,
        "preserve_insertion_order": False,
    }
    Path(working_path).mkdir(parents=True, exist_ok=True)
    with duckdb.connect(
        database=database,
        read_only=False,
        config=config,
    ) as local_db:
        try:
            yield local_db
        finally:
            local_db.close()
