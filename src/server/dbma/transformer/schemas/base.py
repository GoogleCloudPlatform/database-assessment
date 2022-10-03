from pathlib import Path
from typing import Optional, Type, Union

from packaging.version import LegacyVersion, Version
from pydantic import PyObject
from typing_extensions import Self

from dbma import log
from dbma.config import BaseSchema

__all__ = ["CollectionConfig", "BaseCollection", "VersionProfile", "CollectionFileSchema"]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


class CollectionFileSchema(BaseSchema):
    extract_file: str
    extract_model: PyObject | None


class BaseCollection(BaseSchema):
    """Base Schema for file Collection"""

    _file_mapper: dict[str, str] = {}

    @classmethod
    def from_file_list(cls, files: list[Path]) -> Self:  # type: ignore[valid-type]
        """Returns first values in a list or None"""
        return cls.parse_obj(
            {key: cls._match_from_list(value, [str(f.name) for f in files]) for key, value in cls._file_mapper.items()}
        )

    @classmethod
    def _to_path(cls, list_of_values: Optional[list[str]]) -> Optional[Path]:
        """Returns first values in a list or None"""
        if list_of_values:
            return Path(list_of_values[0])
        return None

    @classmethod
    def _match_from_list(cls, match_string: str, list_of_values: list[str]) -> str | None:
        for value in list_of_values:
            if value.startswith(match_string):
                return value
        return None


class CollectionConfig(BaseSchema):
    delimiter: str = "|"
    collection_schema: Type[BaseCollection]
    sql_files_path: str


class VersionProfile(BaseSchema):
    min_version: ScriptVersionType
    max_version: ScriptVersionType
    config: CollectionConfig
