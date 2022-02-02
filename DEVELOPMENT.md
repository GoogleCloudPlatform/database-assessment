# Developing the Optimus Prime Database Assessment tool

The tool is comprised of 2 components:

1. The optimus prime script - the tool that runs on the user's computer
- This scipt performs the 

2. The optimus prime API
- This tool loads the 

## The Optimus Prime API

This api is responsible for uploading the assessment data in the correct format to a BigQuery Dataset.

### How to run locally

#### via Flask locally

1. `pip install -r api-requirements.txt`
1. `pip install -r requirements.txt`
1. `cd db_assessment/`
1. `FLASK_ENV=dev FLASK_APP=api python -m flask run`

#### via Docker locally

1. `pip install -r build-requirements.txt`
1. `invoke build`
1. `invoke run`

#### How to test
1. `pip install -r build-requirements.txt`
1. `invoke pull-config`
1. `invoke test --local --base-url localhost:8080`
This will test the api by using the `sample/datacollection` files to upload to the bigquery dataset via the running api
