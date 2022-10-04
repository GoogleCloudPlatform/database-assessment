from pathlib import Path

from packaging.version import parse as parse_version

from dbma import log
from dbma.__version__ import __version__
from dbma.config import BASE_DIR
from dbma.transformer.schemas import v2xx, v3xx
from dbma.transformer.schemas.base import CollectionConfig, VersionProfile

logger = log.get_logger()

version_config_map = [
    VersionProfile(
        min_version=parse_version("3.0.0"),
        max_version=parse_version(__version__),
        config=CollectionConfig(
            delimiter="|",
            collection_schema=v3xx.CollectionSchema,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v3xx" / "sql")),
        ),
    ),
    VersionProfile(
        min_version=parse_version("2.0.0"),
        max_version=parse_version("2.99.0"),
        config=CollectionConfig(
            delimiter=",",
            collection_schema=v2xx.CollectionSchema,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v2xx" / "sql")),
        ),
    ),
]


def get_config_for_version(script_version: str) -> CollectionConfig:
    """Get the correct collection config for the specified version

    Args:
        version (str): The version number of compare

    Returns:
        CollectionConfig: _description_
    """
    version = parse_version(script_version)
    for version_profile in version_config_map:
        if version_profile.min_version <= version <= version_profile.max_version:
            return version_profile.config
    raise NotImplementedError("The specified version is not implemented")
