# Copyright 2021 Google LLC
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


# Messages handling
import logging
import os
from typing import TYPE_CHECKING, Optional

import google.auth
import requests

# Import to Big Query
from db_assessment import import_db_assessment

if TYPE_CHECKING:
    from db_assessment.api import AppConfig

logger = logging.getLogger()
logger.setLevel(level=logging.INFO)


def get_id_token() -> Optional[str]:
    """Get user ID token"""
    credentials, _ = google.auth.default()
    credentials.refresh(google.auth.transport.requests.Request())
    return credentials.id_token


def run_remote(args: "AppConfig") -> None:
    """Run remote execution"""
    id_token = os.getenv("ID_TOKEN") or get_id_token()
    headers = {"Authorization": f"Bearer {id_token}"}
    config = {
        "projectId": args.project_name,
        "dataset": args.dataset,
        "collectionId": args.collection_id,
    }
    collection_id = args.collection_id or ""
    file_pattern = f"{args.files_location}/*{collection_id.replace(' ', '')}.csv"

    files: dict[str, str] = {}

    # Getting a list of files from OS based on the pattern provided
    # This is the default directory to have all customer database results from oracle_db_assessment.sql
    filename_list = import_db_assessment.list_files(file_pattern)
    for filename in filename_list:
        with open(filename, "r", encoding="UTF-8") as content:
            files.update({filename: content.read()})
    result = requests.post(
        f"{args.remote_url}/api/loadAssessment",
        files=files,
        data=config,
        headers=headers,
        timeout=300,
    )
    result.raise_for_status()
    logging.info(result.text)
