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

from packaging.version import parse as parse_version

from dbma import log
from dbma.__version__ import __version__
from dbma.config import BASE_DIR
from dbma.transformer.schemas import v2xx, v3xx, v4xx, v38x
from dbma.transformer.schemas.base import CollectionConfig, CollectionVersionConfig

logger = log.get_logger()

mapper = [
    # we put the most recent version first so that is the most likely config to be used
    CollectionVersionConfig(
        min_version=parse_version("4.0.0"),
        max_version=parse_version(__version__),
        config=CollectionConfig(
            delimiter="|",
            collection_files_schema=v4xx.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v4.0.0" / "sql")),
        ),
    ),
    CollectionVersionConfig(
        min_version=parse_version("3.0.8"),
        max_version=parse_version("3.99.99"),
        config=CollectionConfig(
            delimiter="|",
            collection_files_schema=v38x.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v3.0.8" / "sql")),
        ),
    ),
    CollectionVersionConfig(
        min_version=parse_version("2.0.6"),
        max_version=parse_version("3.0.7"),
        config=CollectionConfig(
            delimiter="|",
            collection_files_schema=v3xx.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v2.0.6" / "sql")),
        ),
    ),
    CollectionVersionConfig(
        min_version=parse_version("0.0.0"),
        max_version=parse_version("2.0.5"),
        config=CollectionConfig(
            delimiter=",",
            collection_files_schema=v2xx.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v0.0.0" / "sql")),
        ),
    ),
]


def get_config_for_version(script_version: str) -> CollectionConfig:
    """Get the correct collection config for the specified version

    Args:
        version (str): The version number of compare

    Returns:
        CollectionConfig: _description_
    """
    version = parse_version(script_version)

    for version_profile in mapper:
        if version_profile.min_version <= version <= version_profile.max_version:
            return version_profile.config
    raise NotImplementedError("The specified version is not implemented")
