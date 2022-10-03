from pathlib import Path
from tempfile import TemporaryDirectory
from typing import Generator, Optional

from pydantic import ValidationError

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
    parsed_collections = []
    for extract in collections:
        version = parse_as_version or identify_collection_version_from_name(collection.stem)
        config = get_config_for_version(version)
        logger.info('=> config specifies the "%s" character as the delimiter', config.delimiter)
        files = extract_collection(extract, extract_path)
        try:
            collection = config.collection_schema.from_file_list(files)
        except ValidationError as e:
            logger.error("failed to validate files contained in collections: %s", e.errors)
        parsed_collections.append(collection)
        logger.info(collection)
    for collection in parsed_collections:
        files_to_load = collection.dict(exclude_none=True)
        for file_type, file_name in files_to_load.items():
            logger.info(sql.read_csv(f"{extract_path}/{file_name}"))


sql = SQLManager(engine_type="duckdb", sql_files_path=str(Path(BASE_DIR / "transformer" / "sql")))
