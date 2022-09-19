
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

### Import logging & helper functions
##############################################################################
source $__dir/_script_bootstrap.sh
trap _exit ERR

### Validate input
##############################################################################
info "verifying environment before configuring database"
if [ "${GOOGLE_CLOUD_PROJECT}" == "" ]; then
    error "Please ensure GOOGLE_CLOUD_PROJECT is set properly."
fi
if [ "${GOOGLE_CLOUD_REGION}" == "" ]; then
    error "Please ensure GOOGLE_CLOUD_REGION is set properly."
fi
if [ "${GOOGLE_BIGQUERY_DATASET}" == "" ]; then
    error "Please ensure GOOGLE_BIGQUERY_DATASET is set properly."
fi
if [ "${ORACLE_USER}" == "" ]; then
    error "Please ensure ORACLE_USER is set properly."
fi
if [ "${ORACLE_PASSWORD}" == "" ]; then
    error "Please ensure ORACLE_PASSWORD is set properly."
fi

CONNECT_STRING="$ORACLE_USER/\"${ORACLE_PASSWORD}\"@${ORACLE_HOST}:${ORACLE_PORT}/${ORACLE_SERVICE} as sysdba"

info "Launching Optimus Prime Collection Process"

type nawk 1>/dev/null 2>&1 && AWK=nawk || AWK=awk
function processOracleInstallation() {
    info "Locating Oracle installation"
    echo '@sql/op_collect.sql' | sqlcmd "$CONNECT_STRING"
}

function executeScript() {
    info "Starting Script"
    local cmdResult=""
    cmdResult="$(printf "\nexit;" | sqlplus -s -l "${CONNECT_STRING}" @sqlscript_to_run)"
    if [ "$(echo ${cmdResult} | grep 'Some sort of check in the stdout.' || true)" == "Some sort of check in the stdout." ]; then
        info "It was found in th std out"
    fi


}


# MAIN
info "Executing script in DB: ${ORACLE_SERVICE}"
# create tablespace if it doesn't exist
TABLESPACE_EXISTS_SQL=$(
    cat <<SQLPLUS
select 
    case 
        when sum(row_count) > 0 then 'tablespace_found' 
        else 'tablespace_not_found' 
    end obj_count
from (
    select count(1) row_count
    from dba_tablespaces
    where tablespace_name in ('FOOBAR')
);
SQLPLUS
)
TABLESPACE_EXISTS="$(echo ${TABLESPACE_EXISTS} | sqlcmd "$CONNECT_STRING")"
info "result of tablespace lookup: ${TABLESPACE_EXISTS}"
if [ "$(echo ${TABLESPACE_EXISTS} | grep 'tablespace_not_found' || true)" == "tablespace_not_found" ]; then
    createTablespace
    info "created tablespace"
fi
if [ "$(echo ${TABLESPACE_EXISTS} | grep 'tablespace_found' || true)" == "tablespace_found" ]; then
    info "tablespace existed.  skipping creation"
fi
# exec script
executeScript