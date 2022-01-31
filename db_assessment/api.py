from flask import Flask, request
from werkzeug.utils import secure_filename
from tempfile import TemporaryDirectory
import os
from optimusprime import runMain


app = Flask(__name__)


@app.route("/api/loadAssesment", methods=["POST"])
def loadAssesment():
    print(f"{len(request.files)} files uploaded")
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
