THISDIR=$(pwd)
python3 -m venv ${OP_WORKING_DIR}/../op-venv
source ${OP_WORKING_DIR}/../op-venv/bin/activate
cd ${OP_WORKING_DIR}/..

pip3 install pip --upgrade
pip3 install .
cd ${THISDIR}
