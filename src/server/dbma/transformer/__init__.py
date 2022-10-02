from pathlib import Path

from dbma.config import BASE_DIR
from dbma.db import SQLManager

__all__ = ["sql"]

transformer = SQLManager(engine_type="duckdb", sql_files_path=str(Path(BASE_DIR / "transformer" / "sql")))
