#!/usr/bin/env bash

### Setup directories and options needed for execution
#############################################################################

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR=$(dirname ${SCRIPT_DIR})
export VENV_DIR="${BASE_DIR}/.venv"
export VENV_EXISTS=$(cd ${SCRIPT_DIR} && python3 -c "if __import__('pathlib').Path('../.venv/bin/activate').exists(): print('yes')")
TMP_DIR=${BASE_DIR}/tmp
LOG_DIR=${BASE_DIR}/log

if [ ! -d ${TMP_DIR} ]; then
   mkdir -p ${TMP_DIR}
fi
if [ ! -d ${LOG_DIR} ]; then
   mkdir -p ${LOG_DIR}
fi

source ${SCRIPT_DIR}/_configure_op_env.sh

if [ $VENV_EXISTS ]; then 
   echo "Existing environment found"
fi
if [ ! $VENV_EXISTS ];
   then python3 -m venv ${VENV_DIR}
fi

source ${VENV_DIR}/bin/activate
pip3 install pip wheel setuptools --upgrade
#pip3 install .
pip3 install ${BASE_DIR}
cd ${BASE_DIR}

exit 0
