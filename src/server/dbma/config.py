"""
All configuration is via environment variables.

Take not of the environment variable prefixes required for each settings class, except
[`AppSettings`][starlite_lib.config.AppSettings].
"""
import logging
import sys
from datetime import datetime
from enum import Enum, EnumMeta
from functools import lru_cache
from typing import Any, Final, Optional

from pydantic import BaseSettings as _BaseSettings
from pydantic import SecretBytes, SecretStr, ValidationError
from typing_extensions import Literal

from dbma import utils
from dbma.__version__ import __version__

__all__ = ["BASE_DIR", "BaseSchema", "EnvironmentSettings", "Settings", "settings"]
BASE_DIR: Final = utils.module_loading.module_to_os_path("dbma")


logger = logging.getLogger()


class BaseSchema(_BaseSettings):
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
        env_file = ".env"
        env_file_encoding = "utf-8"


class EnvironmentSettings(_BaseSettings):
    """Env Settings"""

    class Config:
        """Base Settings Config"""

        env_file = ".env"
        env_file_encoding = "utf-8"


class Settings(EnvironmentSettings):
    """Settings file"""

    version_number: str = __version__
    log_level: str = "INFO"
    storage_backend: Literal["file", "gcs"] = "gcs"
    google_project_id: Optional[str]
    google_application_credentials: Optional[str] = None
    google_assets_bucket: str = "collection-storage"
    google_runtime_secrets: str = "run-config"

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
        settings = Settings()
    except ValidationError as e:
        logger.fatal("Could not load settings. %s", e)
        sys.exit(1)
    return settings


settings = get_settings()
