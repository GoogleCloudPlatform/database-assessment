from __future__ import annotations

import tempfile
from contextlib import contextmanager
from pathlib import Path
from typing import TYPE_CHECKING

import duckdb

if TYPE_CHECKING:
    from collections.abc import Iterator


@contextmanager
def get_duckdb_connection(working_path: Path | None = None) -> Iterator[duckdb.DuckDBPyConnection]:
    """Yield a new duckdb connections and automatically manages resource cleanup."""
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
        database=f"{working_path!s}/assessment.db",
        read_only=False,
        config=config,
    ) as local_db:
        try:
            # for extension in extensions:
            """
            local_db.execute("SET disabled_optimizers TO 'join_order'")
            """
            yield local_db
        finally:
            local_db.close()
