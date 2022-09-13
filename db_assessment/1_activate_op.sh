#!/usr/bin/env bash
set -eo pipefail 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="${SCRIPT_DIR}/.."
VENV_DIR="${SCRIPT_DIR}/../op-venv"

python3 -m venv ${VENV_DIR}
source ${VENV_DIR}/bin/activate
pip3 install pip wheel setuptools --upgrade
pip3 install .
cd ${BASE_DIR}
