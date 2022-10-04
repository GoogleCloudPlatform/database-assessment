import tarfile as tf
import zipfile as zf
from pathlib import Path
from typing import TYPE_CHECKING

from dbma import log
from dbma.__version__ import __version__

if TYPE_CHECKING:

    from tempfile import TemporaryDirectory


__all__ = [
    "identify_collection_version_from_name",
    "extract_collection",
]


logger = log.get_logger()


def identify_collection_version_from_name(collection: str) -> str:
    """Identify the collection script version used"""
    logger.info("identifying version from %s", collection)
    return __version__


def extract_collection(collection: "Path", extract_path: "TemporaryDirectory | Path") -> "list[Path]":
    """Extracts the specified collection to the specified directory."""
    logger.info("=> searching %s for files and extracting to %s", collection.name, extract_path)
    if collection.suffix in {".gz", ".tgz"}:
        with tf.TarFile.open(collection, "r|gz") as archive:
            archive.extractall(str(extract_path))
            return list(Path(str(extract_path)).glob("*.csv"))
    if collection.suffix in {".zip"}:
        with zf.ZipFile(collection, "r") as archive:
            archive.extractall(str(extract_path))
            return list(Path(str(extract_path)).glob("*.csv"))
    raise NotImplementedError("Could not find collections to extract")
