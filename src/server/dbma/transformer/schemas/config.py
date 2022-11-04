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
from typing import Final

from packaging.version import parse as parse_version

from dbma import log
from dbma.__version__ import __version__
from dbma.config import BASE_DIR
from dbma.transformer.schemas import v000, v206, v308
from dbma.transformer.schemas.base import CollectionConfig, CollectionVersionConfig

logger = log.get_logger()
CANONICAL_PATH: Final = str(Path(BASE_DIR / "transformer" / "schemas" / "canonical" / "sql"))
mapper = [
    # we put the most recent version first so that is the most likely config to be used
    CollectionVersionConfig(
        min_version=parse_version("3.0.8"),
        max_version=parse_version(__version__),
        config=CollectionConfig(
            delimiter="|",
            collection_files_schema=v308.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v308" / "sql")),
            canonical_path=CANONICAL_PATH,
        ),
    ),
    CollectionVersionConfig(
        min_version=parse_version("2.0.6"),
        max_version=parse_version("3.0.7"),
        config=CollectionConfig(
            delimiter="|",
            collection_files_schema=v206.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v206" / "sql")),
            canonical_path=CANONICAL_PATH,
        ),
    ),
    CollectionVersionConfig(
        min_version=parse_version("0.0.0"),
        max_version=parse_version("2.0.5"),
        config=CollectionConfig(
            delimiter=",",
            collection_files_schema=v000.CollectionFiles,
            sql_files_path=str(Path(BASE_DIR / "transformer" / "schemas" / "v000" / "sql")),
            canonical_path=CANONICAL_PATH,
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
