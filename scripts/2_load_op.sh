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

RUNID=$(date +%Y%m%d%H%M%S)
${VENV_DIR}/bin/optimus-prime --sep "${COLSEP}" --dataset ${DSNAME} --delete-dataset --files-location ${OPOUTPUTDIR} \
   --project-name ${PROJECTNAME} --collection-id "" --collection-version ${COLLECTION_VERSION} |& tee ${LOG_DIR}/opload-${DSNAME}-${RUNID}.log
echo ""
echo "The log of this upload is available at:"
echo ""
ls -lrt ${LOG_DIR}/opload-${DSNAME}-${RUNID}.log
echo ""
cd ${SCRIPT_DIR}
exit 0
