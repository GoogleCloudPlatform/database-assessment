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
from typing import Literal, Optional

from flask import Flask, request
from werkzeug.utils import secure_filename

from db_assessment.optimusprime import run_main

app = Flask(__name__)
logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)


@dataclass
class AppConfig:
    """Application Configuration"""

    config_path: str = "db_assessment/opConfig/transformers.json"
    dataset: Optional[str] = None
    project_name: Optional[str] = None
    collection_id: Optional[str] = None
    db_version: Optional[str] = None
    files_location: str = "dbResults"
    sep: str = "|"
    collection_version: str = "0.0.0"
    schema_detection: Literal["AUTO", "FILLGAP"] = "FILLGAP"
    delete_dataset: bool = False
    from_dataframe: bool = False
    consolidate_logs: bool = False
    consolidate_dataframes: bool = False
    import_comment: str = ""
    filter_by_sql_version: str = ""
    filter_by_db_version: str = ""
    load_type: str = "WRITE_APPEND"
    skip_validations: bool = False


@app.route("/api/loadAssessment", methods=["POST"])
def load_assessment():
    """Load an uploaded assessment"""
    app.logger.info(f"{len(request.files)} files uploaded")
    if len(request.files) <= 0:
        return "No files uploaded", 400
    with TemporaryDirectory() as temp_dir:
        for file in request.files.values():
            app.logger.info(f"saved {file.filename}")
            file_path = os.path.join(temp_dir, secure_filename(file.filename))
            app.logger.info(f"saved {file.filename} as {file_path}")
            file.save(file_path)

        request_data = request.form
        config = AppConfig(
            files_location=temp_dir,
            dataset=request_data.get("dataset", None),
            collection_id=request_data.get("collectionId", None),
            project_name=request_data.get("projectId", None),
        )
        run_main(config)
    return "", 201
