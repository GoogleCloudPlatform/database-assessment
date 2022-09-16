
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
__dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
__file="${__dir}/$(basename "${BASH_SOURCE[0]}")"
__base="$(basename "${__file}" .sh)"
__venv_dir="${__dir}/../.venv"
__python_prefix="${__dir}/bin/"


### Import logging & helper functions
##############################################################################
source $__dir/_script_bootstrap.sh
trap _exit ERR

function installPackage() {
    info "Installing and upgrading packages."
    cmdResult="$(${__python_prefix}pip3 install pip wheel setuptools cython --upgrade)"
    check_return_status
    cmdResult="$(${__python_prefix}pip3 install .)"
    check_return_status
}

function createVenv() {
    info "Creating new virtual environment."
    local cmdResult=""
    cmdResult="$(python3 -m venv ${__venv_dir})"
    check_return_status
    info "virtual environment created successfully"

}

info "Preparing to configure Optimus Prime python environment"
# MAIN

info "Looking for Python virtual environment"
VENV_EXIST=$(cd $__dir && python3 -c "if __import__('pathlib').Path('../.venv/bin/activate').exists(): print('yes')")
info "venv lookup found: ${VENV_EXISTS}"
if [ "$(echo ${VENV_EXISTS} | grep 'yes' || true)" == "yes" ]; then
    info "existing environment found.  skipping creation"
else
   createVenv 
fi
installPackage