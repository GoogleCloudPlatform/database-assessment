import zipfile as zf
from typing import TYPE_CHECKING, Union

from packaging.version import LegacyVersion, Version
from packaging.version import parse as parse_version

from dbma import log
from dbma.config import BaseSettings

if TYPE_CHECKING:
    from pathlib import Path

__all__ = [
    "CollectionConfig",
    "version_config_map",
    "get_config_for_version",
    "identify_collection_version",
    "extract_collection",
]


logger = log.get_logger()


class CollectionConfig(BaseSettings):
    default_delimiter: str = "|"


version_config_map = {
    ">=3.0.0": CollectionConfig(default_delimiter="|"),
    "<3.0.0": CollectionConfig(default_delimiter=","),
}


def identify_collection_version(collection_path: "Path") -> str:
    """Identify the collection script version used"""
    logger.info("identifying version from %s", collection_path)
    return "v3.0.6"


def get_config_for_version(script_version: str) -> CollectionConfig:
    """Get the correct collection config for the specified version

    Args:
        version (str): The version number of compare

    Returns:
        CollectionConfig: _description_
    """
    version = parse_version(script_version)
    last_match: Union["Version", "LegacyVersion"] | None = None
    matched_config: "CollectionConfig" | None = None
    for key, value in version_config_map.items():
        parsed_version = parse_version(key)
        if version >= parsed_version and ((last_match and last_match >= parsed_version) or last_match is None):
            last_match = parsed_version
            matched_config = value
    if matched_config:
        return matched_config
    raise NotImplementedError("The specified version is not implemented")


def extract_collection(collection: str, target_path: str) -> None:
    """Extracts the specified collection to the specified directory."""
    with zf.ZipFile(collection, "r") as archive:
        archive.extractall(target_path)
