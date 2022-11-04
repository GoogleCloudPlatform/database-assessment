# Copyright 2022 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
from pathlib import Path
from typing import Optional, Type, Union

from packaging.version import LegacyVersion, Version

from dbma import log
from dbma.config import BaseSchema
from dbma.transformer.manager import SQLManager

__all__ = [
    "CollectionConfig",
    "CollectionFiles",
    "CollectionVersionConfig",
]

logger = log.get_logger()

ScriptVersionType = Union[Version, LegacyVersion]


class CollectionFiles(BaseSchema):
    """Base Schema for file Collection"""

    _delimiter: str = "|"

    @classmethod
    def from_file_list(cls, files: list[Path]) -> "CollectionFiles":
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


class CollectionConfig(BaseSchema):
    delimiter: str = "|"
    pre_process_files: bool = False
    collection_files_schema: Type[CollectionFiles]
    sql_files_path: str
    canonical_path: str


class CollectionVersionConfig(BaseSchema):
    min_version: ScriptVersionType
    max_version: ScriptVersionType
    config: CollectionConfig


class Collection(BaseSchema):
    collection_id: str
    collection_key: str
    db_version: str
    script_version: "Union[LegacyVersion, Version]"
    config: CollectionConfig
    files: CollectionFiles
    queries: SQLManager
