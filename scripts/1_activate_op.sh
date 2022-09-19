#!/usr/bin/env bash
set -eo pipefail 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/.."
export VENV_DIR="${SCRIPT_DIR}/../.venv"
export VENV_EXISTS=$(cd $SCRIPT_DIR && python3 -c "if __import__('pathlib').Path('../.venv/bin/activate').exists(): print('yes')")

if [ $VENV_EXISTS ]; then echo "Existing environment found"; fi
if [ ! $VENV_EXISTS ]; then python3 -m venv ${VENV_DIR}; fi
source ${VENV_DIR}/bin/activate
pip3 install pip wheel setuptools --upgrade
pip3 install .
cd ${BASE_DIR}
