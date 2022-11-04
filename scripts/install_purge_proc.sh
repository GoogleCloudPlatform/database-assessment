#!/usr/bin/env bash
set -x
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

#sed "s/projectID.dataset/${PROJECTNAME}.${DSNAME}/g" ${SCRIPT_DIR}/op_etl_template.sql > ${TMP_DIR}/op_etl_${DSNAME}.sql
#retval=$?
#if [ ${retval} -ne 0 ]; then
#   echo "Error creating purge procedure.  Exiting...."
#   exit 1
#fi

THESQL=$(cat "${SCRIPT_DIR}/purge_collection.sql" | sed "s/projectID.dataset/${PROJECTNAME}.${DSNAME}/g" )

echo ${THESQL} | bq query  --use_legacy_sql=false 

retval=$?
if [ ${retval} -ne 0 ]; then
   echo "Error loading creating purge procedure in BigQuery.  Exiting...."
   exit 1
fi
echo ""
echo "Purge collection procedure created"

THESQL=$(cat "${SCRIPT_DIR}/purge_host.sql" | sed "s/projectID.dataset/${PROJECTNAME}.${DSNAME}/g" )

echo ${THESQL} | bq query  --use_legacy_sql=false 

retval=$?
if [ ${retval} -ne 0 ]; then
   echo "Error loading creating purge procedure in BigQuery.  Exiting...."
   exit 1
fi
echo ""
echo "Purge host procedure created"
exit 0

