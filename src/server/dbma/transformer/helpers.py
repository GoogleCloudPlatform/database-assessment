import tarfile as tf
import zipfile as zf
from pathlib import Path
from tempfile import TemporaryDirectory
from typing import TYPE_CHECKING, Generator

import duckdb

from dbma import log
from dbma.__version__ import __version__

if TYPE_CHECKING:
    from duckdb import DuckDBPyConnection
    from pyarrow.lib import Table as ArrowTable

__all__ = ["identify_collection_version_from_name", "extract_collection", "get_temp_dir"]


logger = log.get_logger()


def get_temp_dir() -> Generator[TemporaryDirectory, None, None]:
    with TemporaryDirectory() as d:
        yield d  # type: ignore


def identify_collection_version_from_name(collection: str) -> str:
    """Identify the collection script version used"""
    logger.info("identifying version from %s", collection)
    return __version__


def extract_collection(collection: "Path", extract_path: "TemporaryDirectory | Path") -> "list[Path]":
    """Extracts the specified collection to the specified directory."""
    logger.debug("🔎 searching %s for files and extracting to %s", collection.name, extract_path)
    if collection.suffix in {".gz", ".tgz"}:
        with tf.TarFile.open(collection, "r|gz") as archive:
            archive.extractall(str(extract_path))
            return list(Path(str(extract_path)).glob("*.csv"))
    if collection.suffix in {".zip"}:
        with zf.ZipFile(collection, "r") as archive:
            archive.extractall(str(extract_path))
            return list(Path(str(extract_path)).glob("*.csv"))
    raise NotImplementedError("Could not find collections to extract")


# def csv_to_arrow(file: Path):
#     """Converts a csv to an arrow dataframe"""


class CSVTransformer:
    """Transforms a CSV to various formats"""

    def __init__(self, file_path: Path, delimiter: str = "|", has_headers: bool = True, skip_rows: int = 0) -> None:
        self.file_path = file_path
        self.delimiter = delimiter
        self.has_headers = has_headers
        self.skip_rows = skip_rows
        self.local_db = duckdb.connect()

    def to_arrow_table(self, chunk_size: int = 1000000) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.arrow(chunk_size)

    def to_parquet(self) -> Path:
        """Converts the CSV to an arrow table"""
        file_name = f"{self.file_path.parent}/{self.file_path.stem}.parquet"
        sql = f"""--sql
            COPY (
            select * from read_csv_auto(?, delim = ?, header = ?)
            ) TO '{file_name}' (FORMAT 'parquet')
        """
        self.local_db.execute(
            sql,
            [
                str(self.file_path),
                self.delimiter,
                self.has_headers,
            ],
        )
        return Path(file_name)

    def to_df(self) -> "ArrowTable":
        """Converts the CSV to an arrow table"""
        data = self._select_data()
        return data.df()

    def _select_data(self) -> "DuckDBPyConnection":
        """Select the data from the CSV"""
        results = self.local_db.execute(
            """--sql
            select * from read_csv_auto(?, delim = ?, header = ?)
        """,
            [str(self.file_path), self.delimiter, self.has_headers],
        )
        return results
