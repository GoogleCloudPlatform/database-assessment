from typing import TYPE_CHECKING

from dbma import log

if TYPE_CHECKING:
    from pathlib import Path

logger = log.get_logger()


def identify_collection_version(collection: "Path") -> str:
    """Identify the collection script version used"""
    logger.info("identifying version from %s", str(collection))
    return "v3.0.6"
