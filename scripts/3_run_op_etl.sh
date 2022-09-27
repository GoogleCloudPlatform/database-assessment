#!/usr/bin/env bash

### Setup directories and options needed for execution
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR=$(dirname ${SCRIPT_DIR})
TMP_DIR=${BASE_DIR}/tmp
LOG_DIR=${BASE_DIR}/log

if [ ! -d ${TMP_DIR} ]; then
   mkdir -p ${TMP_DIR}
fi
if [ ! -d ${LOG_DIR} ]; then
   mkdir -p ${LOG_DIR}
fi

source ${SCRIPT_DIR}/_configure_op_env.sh

sed "s/projectID.dataset/${PROJECTNAME}.${DSNAME}/g" ${BASE_DIR}/db_assessment/op_etl_template.sql > ${TMP_DIR}/op_etl_${DSNAME}.sql
retval=$?
if [ ${retval} -ne 0 ]; then
   echo "Error creating ${TMP_DIR}/op_etl_${DSNAME}.sql.  Exiting...."
   exit 1
fi

bq query  --use_legacy_sql=false < ${TMP_DIR}/op_etl_${DSNAME}.sql  | tee ${LOG_DIR}/op_etl_${DSNAME}.log
if [ ${retval} -ne 0 ]; then
   echo "Error loading Optimus Prime Collection into BigQuery.  Exiting...."
   exit 1
fi
echo ""
echo "A log of this process is available at ${LOG_DIR}/op_etl_${DSNAME}.log"
exit 0
