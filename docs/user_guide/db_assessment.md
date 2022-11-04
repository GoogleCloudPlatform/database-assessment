# Usage

## Upload & Process Collections

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

### Prepare Collections

The utility expects to receive the compressed archives for processing.
Ex:

```shell
mkdir ~/data
<upload files to data>
cd data
<decompress files>
```

### Configure automation

The automated load process is configured via setting several environment variables and then executing a set of scripts from the base of the git repository.

Set these environment variables prior to starting the data load process:

```shell
# Required
# This is the name of the project into which you want to load data
export PROJECTNAME=yourProjectNameHere

# Required
# This is the name of the data set into which you want to load.
# The dataset will be created if it does not exist.
# If the datset already exists, it will have this data appoended.
# Use only alphanumeric characters, - (dash) or _ (underscore)
# This name must be filesystem and html compatible
export DSNAME=yourDatasetNameHere

# Required
# This is the location in which the dataset should be created.
export DSLOC=yourRegionNameHere

# Required
# This is the full path into which the customer's files have been extracted.
export OPOUTPUTDIR=/full/Path/To/CollectionFiles

# Optional
# This is the name of the report you want to create in DataStudio upon load completion.
# Use only alphanumeric characters or embed HTML encoding.
# Defaults to "OptimusPrime%20Dashboard%20${DSNAME}"
export REPORTNAME=yourReportNameHere

# Optional
# This is the column separator used in the input data files.
# Previous versions of Optimus Prime used ';' (semicolon).
# Defaults to | (pipe)
export COLSEP='|'
```

### Execute the load scripts

The load scripts expect to be run from the <workingdirectory>/oracle-database-assessment/scripts directory. Change to this directory and run the following commands in numeric order. Check output of each for errors before continuing to the next.

```shell
./scripts/1_activate_op.sh
./scripts/2_load_op.sh
./scripts/3_run_op_etl.sh
./scripts/4_gen_op_report_url.sh
```

The function of each script is as follows.

- \_configure_op_env.sh - Defines environment variables that are used in the other scripts. This script is executed only by the other scripts in the loading process.
- 1_activate_op.sh - Installs necessary Python support modules and activates the Python virtual environment for Optimus Prime.
- 2_load_op.sh - Loads the client data files into the base Optimus Prime tables in the requested data set.
- 3_run_op_etl.sh - Installs and runs Big Query procedures that create additional views and tables to support the Optimus Prime dashboard.
- 4_gen_op_report_url.sh - Generates the URL to view the newly loaded data using a report template.

## Step 3 - Analyzing imported data

### Clone DataStudio report

Click the link displayed by script 4_gen_op_report_url.sh to view the report. Note that this link does not persist the report.
To save the report for future use, click the '"Edit and Share"' button, then '"Acknowledge and Save"', then '"Add to Report"'. It will then show up in Data Studio in '"Reports owned by me"' and can be shared with others.

Skip to step 3 to perform additional analysis for anything not contained in the dashboard report.

### Open the dataset used in the step 2 of Part 2 in Google BigQuery

- Query the view names starting with vReport\* for further analysis
- Sample queries are listed, they provide
  - Source DB Summary
  - Source Host details
  - Google Bare Metal Sizing
  - Google Bare Metal Pricing
  - Migration Recommendations
