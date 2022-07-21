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

# Basic python built-in libraries to enable read, write and manipulate files in the OS
import os

# Import to Big Query
from db_assessment import import_db_assessment

logging.getLogger().setLevel(level=logging.INFO)


def get_id_token():
    import google.auth

    credentials, _ = google.auth.default()
    credentials.refresh(google.auth.transport.requests.Request())
    return credentials.id_token


def runRemote(args):
    import requests

    id_token = os.getenv("ID_TOKEN") if os.getenv("ID_TOKEN") else get_id_token()
    headers = {"Authorization": f"Bearer {id_token}"}
    config = {
        "projectId": args.projectname,
        "dataset": args.dataset,
        "collectionId": args.collectionid,
    }
    csvFilesLocationPattern = (
        str(args.fileslocation)
        + "/*"
        + str(args.collectionid).replace(" ", "")
        + ".log"
    )

    # Getting a list of files from OS based on the pattern provided
    # This is the default directory to have all customer database results from oracle_db_assessment.sql
    files = import_db_assessment.getAllFilesByPattern(csvFilesLocationPattern)

    files = {file_name: file_name for file_name in files}
    result = requests.post(
        f"{args.remoteurl}/api/loadAssessment",
        files=files,
        data=config,
        headers=headers,
    )
    result.raise_for_status()
    logging.info(result.text)


def grantAccess(projectId, dataset):
    # get OP SA
    op_sa = ""

    # determine BQ role

    # assign IAM

    pass
