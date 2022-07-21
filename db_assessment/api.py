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

import logging
import os
from dataclasses import dataclass
from tempfile import TemporaryDirectory
from typing import Optional

from flask import Flask, request
from werkzeug.utils import secure_filename

from db_assessment.optimusprime import runMain

app = Flask(__name__)
logger = logging.getLogger(__name__)


@dataclass
class UserConfig:
    transformersconfig: str = "db_assessment/opConfig/transformers.json"
    dataset: Optional[str] = None
    projectname: Optional[str] = None
    collectionid: Optional[str] = None
    dbversion: Optional[str] = None
    fileslocation: str = "dbResults"
    sep: str = ","
    collectionversion: str = "0.0.0"
    schemadetection: str = "FILLGAP"
    deletedataset: bool = False
    fromdataframe: bool = False
    consolidatelogs: bool = False
    consolidatedataframes: bool = False
    importcomment: str = ""
    filterbysqlversion: str = ""
    filterbydbversion: str = ""
    loadtype: str = "WRITE_APPEND"
    skipvalidations: bool = False


@app.route("/api/loadAssessment", methods=["POST"])
def loadAssessment():
    logger.info(f"{len(request.files)} files uploaded")
    if len(request.files) <= 0:
        return "No files uploaded", 400
    with TemporaryDirectory() as tmpDir:
        for file in request.files.values():
            logger.info(f"saved {file.filename}")
            filePath = os.path.join(tmpDir, secure_filename(file.filename))
            logger.info(f"saved {file.filename} as {secure_filename(file.filename)}")
            file.save(filePath)

        request_data = request.form
        config = UserConfig(
            fileslocation=tmpDir,
            dataset=request_data.get("dataset", None),
            collectionid=request_data.get("collectionId", None),
            projectname=request_data.get("projectId", None),
        )
        runMain(config)
    return "", 201
