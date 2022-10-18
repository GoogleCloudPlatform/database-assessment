from pathlib import Path
from typing import Optional, Type, Union

from packaging.version import LegacyVersion, Version

from dbma import log
from dbma.config import BaseSchema
from dbma.database import SQLManager

__all__ = [
    "AdvisorExtractConfig",
    "AdvisorExtractFiles",
    "AdvisorExtractVersionConfig",
]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


class AdvisorExtractFiles(BaseSchema):
    """Base Schema for file Collection"""

    _delimiter: str = "|"

    @classmethod
    def from_file_list(cls, files: list[Path]) -> "AdvisorExtractFiles":
        """Returns first values in a list or None"""
        return cls.parse_obj(
            {
                file_type: cls._match_path(file_type, files)
                for file_type in cls.schema(by_alias=True).get("properties", {}).keys()
            }
        )

    @classmethod
    def _match_path(cls, match_string: str, list_of_paths: list[Path]) -> Optional[Path]:
        for value in list_of_paths:
            if value.name.startswith(f"opdb__{match_string}"):
                return value
        return None

    @property
    def delimiter(self) -> str:
        return self._delimiter

    class Config:
        allow_population_by_field_name = True


class AdvisorExtractConfig(BaseSchema):
    delimiter: str = "|"
    pre_process_files: bool = False
    collection_files_schema: Type[AdvisorExtractFiles]
    sql_files_path: str


class AdvisorExtractVersionConfig(BaseSchema):
    min_version: ScriptVersionType
    max_version: ScriptVersionType
    config: AdvisorExtractConfig


class AdvisorExtract(BaseSchema):
    collection_id: str
    collection_key: str
    db_version: str
    script_version: "Union[LegacyVersion, Version]"
    config: AdvisorExtractConfig
    files: AdvisorExtractFiles
    queries: SQLManager
