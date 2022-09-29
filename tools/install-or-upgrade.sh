
#!/usr/bin/env bash
# #################################
#
# #################################
# Exit on error. Append "|| true" if you expect an error.
set -o errexit
# Exit on error inside any functions or subshells.
# set -o errtrace
# # Do not allow use of undefined vars. Use ${VAR:-} to use an undefined VAR
# set -o nounset
# # Catch the error in case mysqldump fails (but gzip succeeds) in `mysqldump |gzip`
set -o pipefail
# # Turn on traces, useful while debugging but commented out by default
# # set -o xtrace

# gather info about the execution path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_FILE_NAME="${SCRIPT_DIR}/$(basename "${BASH_SOURCE[0]}")"
BASE_DIR="$(basename "${SCRIPT_FILE_NAME}" .sh)"
VENV_DIR="${SCRIPT_DIR}/../.venv"
PYTHON_PREFIX="${VENV_DIR}/bin/"

### Import logging & helper functions
##############################################################################
source $SCRIPT_DIR/_script_bootstrap.sh
trap _exit ERR

function installPackage() {
    info "Installing and upgrading packages."
    ${__python_prefix}pip3 install pip wheel setuptools cython --upgrade
    check_return_status
    ${__python_prefix}pip3 install .
    check_return_status
}

function createVenv() {
    info "Creating new virtual environment."
    python3 -m venv ${VENV_DIR}
    check_return_status
    info "virtual environment created successfully"

}

info "Preparing to configure Optimus Prime python environment"
# MAIN

info "Looking for Python virtual environment"
if [ -f "${VENV_DIR}/bin/activate" ]; then
    info "existing environment found.  skipping creation"
else
   createVenv 
fi
installPackage