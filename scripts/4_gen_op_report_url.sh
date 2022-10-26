#!/usr/bin/env bash

### Setup directories and options needed for execution
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR=$(dirname ${SCRIPT_DIR})
VENV_DIR="${BASE_DIR}/.venv"
TMP_DIR=${BASE_DIR}/tmp
LOG_DIR=${BASE_DIR}/log

if [ ! -d ${TMP_DIR} ]; then
   mkdir -p ${TMP_DIR}
fi
if [ ! -d ${LOG_DIR} ]; then
   mkdir -p ${LOG_DIR}
fi

set -eo pipefail

source ${SCRIPT_DIR}/_configure_op_env.sh

# ReportID is taken from the DataStudio template upon which the new report will be created.
REPORTID=ed2d87f1-e037-4e65-8ef0-4439a3e62aa3

# REPORTNAME and DSNAME are set in another script.
# The URL template is formatted for editability and readability.
# Line feeds, carriage returns and spaces will be filtered out when generated.
# Any new data sources added to the template will need to be modified here.
URL_TEMPLATE="https://datastudio.google.com/reporting/create?c.
reportId=${REPORTID}
&r.reportName=${REPORTNAME}
&ds.ds106.connector=bigQuery
&ds.ds106.datasourceName=T_DS_Database_Metrics
&ds.ds106.projectId=${PROJECTNAME}
&ds.ds106.type=TABLE
&ds.ds106.datasetId=${DSNAME}
&ds.ds106.tableId=T_DS_Database_Metrics
&ds.ds96.connector=bigQuery
&ds.ds96.datasourceName=T_DS_BMS_sizing
&ds.ds96.projectId=${PROJECTNAME}
&ds.ds96.type=TABLE
&ds.ds96.datasetId=${DSNAME}
&ds.ds96.tableId=T_DS_BMS_sizing
&ds.ds103.connector=bigQuery
&ds.ds103.datasourceName=V_DS_BMS_BOM
&ds.ds103.projectId=${PROJECTNAME}
&ds.ds103.type=TABLE
&ds.ds103.datasetId=${DSNAME}
&ds.ds103.tableId=V_DS_BMS_BOM
&ds.ds169.connector=bigQuery
&ds.ds169.datasourceName=V_DS_HostDetails
&ds.ds169.projectId=${PROJECTNAME}
&ds.ds169.type=TABLE
&ds.ds169.datasetId=${DSNAME}
&ds.ds169.tableId=V_DS_HostDetails
&ds.ds68.connector=bigQuery
&ds.ds68.datasourceName=V_DS_dbfeatures
&ds.ds68.projectId=${PROJECTNAME}
&ds.ds68.type=TABLE
&ds.ds68.datasetId=${DSNAME}
&ds.ds68.tableId=V_DS_dbfeatures
&ds.ds12.connector=bigQuery
&ds.ds12.datasourceName=V_DS_dbsummary
&ds.ds12.projectId=${PROJECTNAME}
&ds.ds12.type=TABLE
&ds.ds12.datasetId=${DSNAME}
&ds.ds12.tableId=V_DS_dbsummary
&ds.ds137.connector=bigQuery
&ds.ds137.datasourceName=V_DS_BMS_BOM_HT
&ds.ds137.projectId=${PROJECTNAME}
&ds.ds137.type=TABLE
&ds.ds137.datasetId=${DSNAME}
&ds.ds137.tableId=V_DS_BMS_BOM_HT
"

echo ""
echo "The Optimus Prime dashboard report ${REPORTNAME} is available at the link below"
echo ""
echo ${URL_TEMPLATE} | sed 's/\r//g;s/\n//g;s/ //g'
echo ""
echo "Click the link to view the report."
echo "To create a persistent copy of this report:"
echo "Click the \"Edit and Share\" button, then \"Acknowledge and Save\", then \"Add to Report\"."
echo "It will then show up in Data Studio in \"Reports owned by me\" and can be shared with others."
