
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
__python_prefix="${__venv_dir}/bin/"


### Import logging & helper functions
##############################################################################
source $__dir/_script_bootstrap.sh
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
    python3 -m venv ${__venv_dir}
    check_return_status
    info "virtual environment created successfully"

}

info "Preparing to configure Optimus Prime python environment"
# MAIN

info "Looking for Python virtual environment"
if [ -f "${__venv_dir}/bin/activate" ]; then
    info "existing environment found.  skipping creation"
else
   createVenv 
fi
installPackage