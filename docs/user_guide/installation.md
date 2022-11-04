# Usage

## Importing the data collected into Google BigQuery for analysis

Much of the data import and report generation has been automated. Follow section 2.1 to use the automated process. Section 2.2 provides instructions for the manual process if that is your preference. Both processes assume you have rights to create datasets in a Big Query project and access to Data Studio.

Make note of the project name and the data set name and location. The data set will be created if it does not exist.

### Automated load process

These instructions are written for running in a Cloud Shell environment. Ensure that your environment is configured to access the Google Cloud project you want to use:

```shell
gcloud config set project [PROJECT_ID]
```

### Create a workspace for processing

Create a folder where you upload collections and install the latest collection command line processing utility.

```shell
export WORKING_DIR=./migration_advisor
mkdir -p $WORKING_DIR/data
cd $WORKING_DIR
if [ ! -f .venv/bin/activate ]; then
  echo "Creating new virtual environment."
  python3 -m venv .venv
fi
source .venv/bin/activate
pip install -U wheel setuptools cython pip
pip install -U git+https://github.com/GoogleCloudPlatform/oracle-database-assessment.git@main
```

> TIP: Google Cloud Shell is a great place to execute these commands.
