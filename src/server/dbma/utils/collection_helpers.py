import zipfile as zf
from pathlib import Path
from typing import TYPE_CHECKING, Type, Union

from pydantic import PyObject

from dbma import log
from dbma.__version__ import __version__
from dbma.config import BaseSchema

if TYPE_CHECKING:
    from packaging.version import LegacyVersion, Version


__all__ = [
    "CollectionConfig",
    "CollectionSchema",
    "CollectionFileSchema",
    "VersionProfile",
    "identify_collection_version_from_name",
    "extract_collection",
]


logger = log.get_logger()


class CollectionFileSchema(BaseSchema):
    extract_file: str
    extract_model: PyObject


class CollectionSchema:
    """Base Schema for file Collection"""


class CollectionConfig(BaseSchema):
    delimiter: str = "|"
    collection_schema: Type[CollectionSchema]


class VersionProfile(BaseSchema):
    min_version: "Union[Version, LegacyVersion]"
    max_version: "Union[Version, LegacyVersion]"
    config: CollectionConfig


VersionProfile.update_forward_refs()


def identify_collection_version_from_name(collection: str) -> str:
    """Identify the collection script version used"""
    logger.info("identifying version from %s", collection)
    return __version__


def extract_collection(collection: str, extract_path: str) -> list[Path]:
    """Extracts the specified collection to the specified directory."""
    with zf.ZipFile(collection, "r") as archive:
        archive.extractall(extract_path)
        files = list(Path(extract_path).glob(".csv"))
    return files
