from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Generator, Optional

from dbma import log
from dbma.config import BASE_DIR
from dbma.db import SQLManager
from dbma.transformer.helpers import extract_collection, identify_collection_version_from_name
from dbma.transformer.version_maps import get_config_for_version

__all__ = ["sql", "process_collection"]


logger = log.get_logger()


def get_temp_dir() -> Generator[TemporaryDirectory, None, None]:
    with TemporaryDirectory() as d:
        yield d  # type: ignore


def process_collection(
    collections: list["Path"], extract_path: TemporaryDirectory | Path, parse_as_version: Optional[str] = None
) -> None:
    """Process the collection"""
    if parse_as_version:
        logger.info("=> Skipping version analysis and forcing version to be %s", parse_as_version)
    else:
        logger.info("=> Detecting collector version")
    for collection in collections:
        version = parse_as_version or identify_collection_version_from_name(collection.stem)
        config = get_config_for_version(version)
        logger.info('=> config specifies the "%s" character as the delimiter', config.delimiter)
        files = extract_collection(collection, extract_path)
        collection = config.collection_schema.from_file_list(files)
        logger.info(collection)


sql = SQLManager(engine_type="duckdb", sql_files_path=str(Path(BASE_DIR / "transformer" / "sql")))