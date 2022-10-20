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
"""
All configuration is via environment variables.

Take not of the environment variable prefixes required for each settings class, except
[`AppSettings`][starlite_lib.config.AppSettings].
"""
import logging
import sys
from datetime import datetime, timezone
from enum import Enum, EnumMeta
from functools import lru_cache
from pathlib import Path
from typing import Any, Final, Optional, Union

import orjson
from pydantic import BaseModel as _BaseModel
from pydantic import BaseSettings as _BaseSettings
from pydantic import SecretBytes, SecretStr, ValidationError
from typing_extensions import Literal

from dbma import utils
from dbma.__version__ import __version__

__all__ = ["BASE_DIR", "BaseSchema", "BaseSettings", "Settings", "settings"]
BASE_DIR: Final = utils.module_loading.module_to_os_path("dbma")


logger = logging.getLogger()


class BaseSettings(_BaseSettings):
    """Base Settings"""

    class Config:
        """Base Settings Config"""

        json_loads = utils.serializers.deserialize_object
        json_dumps = utils.serializers.serialize_object
        case_sensitive = False
        json_encoders = {
            datetime: utils.serializers.convert_datetime_to_gmt,
            SecretStr: lambda secret: secret.get_secret_value() if secret else None,
            SecretBytes: lambda secret: secret.get_secret_value() if secret else None,
            Enum: lambda enum: enum.value if enum else None,
            EnumMeta: None,
        }
        validate_assignment = True
        orm_mode = True
        use_enum_values = True
        arbitrary_types_allowed = True
        env_file = ".env"
        env_file_encoding = "utf-8"


class BaseSchema(_BaseModel):
    """Base Settings"""

    class Config:
        """Base Settings Config"""

        json_loads = utils.serializers.deserialize_object
        json_dumps = utils.serializers.serialize_object
        case_sensitive = False
        json_encoders = {
            datetime: utils.serializers.convert_datetime_to_gmt,
            SecretStr: lambda secret: secret.get_secret_value() if secret else None,
            SecretBytes: lambda secret: secret.get_secret_value() if secret else None,
            Enum: lambda enum: enum.value if enum else None,
            EnumMeta: None,
        }
        validate_assignment = True
        orm_mode = True
        use_enum_values = True
        arbitrary_types_allowed = True


class Settings(BaseSettings):
    """Settings file"""

    version_number: str = __version__
    log_level: str = "INFO"
    storage_backend: Literal["file", "gcs"] = "gcs"
    google_project_id: str
    google_application_credentials: Optional[str] = None
    collections_path: str = "collection-storage"
    google_runtime_secrets: str = "run-config"
    duckdb_path: str = ":memory:"
    bigquery_dataset: str = "v4-development"
    temp_path: Optional[Path] = None

    @property
    def storage_backend_options(self) -> dict[str, Any]:
        if self.storage_backend == "gcs":
            return {"project": self.google_project_id}
        if self.storage_backend == "file":
            return {}


@lru_cache
def get_settings() -> "Settings":
    """Load Settings file"""
    try:
        settings = Settings.parse_obj({})
    except ValidationError as e:
        logger.fatal("Could not load settings. %s", e)
        sys.exit(1)
    return settings


def serialize_object(value: Any) -> str:
    """Encodes json with the optimized ORJSON package.

    orjson.dumps returns bytearray, so you can't pass it directly as
    json_serializer
    """

    def _serializer(value: Any) -> Any:
        if isinstance(value, SecretBytes):
            return value.get_secret_value()
        raise TypeError

    return orjson.dumps(
        value,
        default=_serializer,
        option=orjson.OPT_NAIVE_UTC | orjson.OPT_SERIALIZE_NUMPY,
    ).decode()


def deserialize_object(value: Union[bytes, bytearray, memoryview, str, dict[str, Any]]) -> Any:
    """Decodes to an object with the optimized ORJSON package.

    orjson.dumps returns bytearray, so you can't pass it directly as
    json_serializer
    """
    if isinstance(value, dict):
        return value
    return orjson.loads(value)


def convert_datetime_to_gmt(dt: datetime) -> str:
    """Handles datetime serialization for nested timestamps in
    models/dataclasses."""
    if not dt.tzinfo:
        dt = dt.replace(tzinfo=timezone.utc)
    return dt.isoformat().replace("+00:00", "Z")


settings = get_settings()
