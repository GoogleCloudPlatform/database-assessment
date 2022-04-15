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

from flask import Flask, request
from werkzeug.utils import secure_filename
from tempfile import TemporaryDirectory
import os
from optimusprime import runMain


app = Flask(__name__)


@app.route("/api/loadAssesment", methods=["POST"])
def loadAssesment():
    print(f"{len(request.files)} files uploaded")
    if len(request.files)<=  0:
        return 'No files uploaded', 400
    with TemporaryDirectory() as tmpDir:
        for file in request.files.values():
            print(file)
            print(file.filename)
            print(secure_filename(file.filename))
            filePath = os.path.join(tmpDir, secure_filename(file.filename))
            file.save(filePath)

        request_data = request.form
        config = UserConfig()
        config.fileslocation = tmpDir
        config.dataset = request_data['dataset']
        config.collectionid = request_data['collectionId']
        config.projectname = request_data['projectId']

        runMain(config)
    return '', 201


class UserConfig:
    transformersConfig = 'opConfig/transformers.json'
    dataset = None
    projectname = None
    collectionid = None
    dbversion = None
    fileslocation = "dbResults"
    transformersconfig = "opConfig/transformers.json"
    sep = ","
    collectionversion = "0.0.0"
    schemadetection = "FILLGAP"
    deletedataset = False
    fromdataframe = False
    consolidatelogs = False
    consolidatedataframes = False
