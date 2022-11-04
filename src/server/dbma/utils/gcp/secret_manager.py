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
import hashlib
from typing import cast

from google.cloud import secretmanager as sm


def get_secret(project_id: str, secret_id: str, version_id: str = "latest") -> str:
    """Load Secret from GCP Secret Manager

    Args:
        project_id (str): _description_
        secret_id (str): _description_
        version_id (str, optional): _description_. Defaults to "latest".

    Returns:
        str: _description_
    """
    client = sm.SecretManagerServiceClient()
    name = f"projects/{project_id}/secrets/{secret_id}/versions/{version_id}"
    response = client.access_secret_version(request={"name": name})
    return cast("str", response.payload.data.decode("UTF-8"))


def secret_hash(secret_value: str) -> str:
    """Get hash of value

    Args:
        secret_value (str): _description_

    Returns:
        str: _description_
    """
    # return the sha224 hash of the secret value
    return hashlib.sha224(bytes(secret_value, "utf-8")).hexdigest()
