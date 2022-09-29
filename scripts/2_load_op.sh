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

source ${SCRIPT_DIR}/_configure_op_env.sh

bq mk --dataset --force=TRUE --data_location=${DSLOC} ${DSNAME}
retval=$?
if [ $retval -ne 0 ]; then
   echo "BigQuery Dataset creation has failed.  Exiting...."
   exit 1
fi
for COLID in $(ls -1 ${OPOUTPUTDIR}/opdb__*.csv| rev | cut -d '.' -f 2 | rev | sort | uniq)
do
   ${VENV_DIR}/bin/optimus-prime --sep "${COLSEP}" --dataset ${DSNAME} --files-location ${OPOUTPUTDIR} \
   --project-name ${PROJECTNAME} --collection-id ${COLID} | tee ${LOG_DIR}/opload-${DSNAME}-${COLID}.log
done
echo ""
echo "Logs of this upload are available at:"
echo ""
ls -l ${LOG_DIR}/opload-${DSNAME}-*.log
echo ""
cd ${SCRIPT_DIR}
exit 0
