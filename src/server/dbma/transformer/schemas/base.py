from pathlib import Path
from typing import Optional, Type, Union

from packaging.version import LegacyVersion, Version

from dbma import log
from dbma.config import BaseSchema

__all__ = [
    "CollectionConfig",
    "BaseCollection",
    "VersionProfile",
]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


class BaseCollection(BaseSchema):
    """Base Schema for file Collection"""

    _file_mapper: dict[str, str] = {}
    _delimiter: str = "|"

    @classmethod
    def from_file_list(cls, files: list[Path]) -> "BaseCollection":
        """Returns first values in a list or None"""
        return cls.parse_obj({key: cls._match_path(value, files) for key, value in cls._file_mapper.items()})

    @classmethod
    def _match_path(cls, match_string: str, list_of_paths: list[Path]) -> Optional[Path]:
        for value in list_of_paths:
            if value.name.startswith(match_string):
                return value
        return None

    @property
    def file_mapper(self) -> dict[str, str]:
        return self._file_mapper

    @property
    def delimiter(self) -> dict[str, str]:
        return self.delimiter


class CollectionConfig(BaseSchema):
    delimiter: str = "|"
    collection_schema: Type[BaseCollection]
    sql_files_path: str


class VersionProfile(BaseSchema):
    min_version: ScriptVersionType
    max_version: ScriptVersionType
    config: CollectionConfig


class CollectionArchive(BaseSchema):
    config: CollectionConfig
    files: BaseCollection
