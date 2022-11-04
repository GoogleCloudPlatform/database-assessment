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

${VENV_DIR}/bin/optimus-prime --sep "${COLSEP}" --dataset ${DSNAME} --delete-dataset --files-location ${OPOUTPUTDIR} \
   --project-name ${PROJECTNAME} --collection-id "" --collection-version ${COLLECTION_VERSION} |& tee ${LOG_DIR}/opload-${DSNAME}-${COLID}.log
echo ""
echo "Logs of this upload are available at:"
echo ""
ls -l ${LOG_DIR}/opload-${DSNAME}-*.log
echo ""
cd ${SCRIPT_DIR}
exit 0
