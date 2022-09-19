#!/usr/bin/env bash
set -eo pipefail 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/.."
VENV_DIR="${SCRIPT_DIR}/../.venv"

bq mk --dataset --force=TRUE --data_location=${DSLOC} ${DSNAME}
for COLID in $(ls -1 ${OP_LOG_DIR}/opdb*| rev | cut -d '.' -f 2 | rev | sort | uniq)
do
${VENV_DIR}/bin/optimus-prime -sep "${COLSEP}" -dataset ${DSNAME} -fileslocation ${OP_LOG_DIR} -projectname ${PROJECTNAME} -collectionid ${COLID} | tee ${SCRIPT_DIR}/opload-${DSNAME}-${COLID}.log
done
echo
echo Logs of this upload are available at:
echo
ls -l ${SCRIPT_DIR}/opload-${DSNAME}-*.log
echo
cd ${SCRIPT_DIR}
