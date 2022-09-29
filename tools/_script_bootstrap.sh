# Define the environment variables (and their defaults) that this script depends on
LOG_LEVEL="${LOG_LEVEL:-6}" # 7 = debug -> 0 = emergency
NO_COLOR="${NO_COLOR:-}"    # true = disable color. otherwise autodetected

### Functions
##############################################################################
function _log() {
    local log_level="${1}"
    shift
    # shellcheck disable=SC2034
    local color_debug="\x1b[35m"
    # shellcheck disable=SC2034
    local color_info="\x1b[32m"
    # shellcheck disable=SC2034
    local color_notice="\x1b[34m"
    # shellcheck disable=SC2034
    local color_warn="\x1b[33m"
    # shellcheck disable=SC2034
    local color_error="\x1b[31m"
    # shellcheck disable=SC2034
    local color_critical="\x1b[1;31m"
    # shellcheck disable=SC2034
    local color_alert="\x1b[1;33;41m"
    # shellcheck disable=SC2034
    local color_fatal="\x1b[1;4;5;33;41m"

    local colorvar="color_${log_level}"

    local color="${!colorvar:-${color_error}}"
    local color_reset="\x1b[0m"

    if [[ "${NO_COLOR:-}" = "true" ]] || ([[ "${TERM:-}" != "xterm"* ]] && [[ "${TERM:-}" != "screen"* ]]) || [[ ! -t 2 ]]; then
        if [[ "${NO_COLOR:-}" != "false" ]]; then
            # Don't use colors on pipes or non-recognized terminals
            color=""
            color_reset=""
        fi
    fi

    # all remaining arguments are to be printed
    local log_line=""

    while IFS=$'\n' read -r log_line; do
        echo -e "$(date -u +"%Y-%m-%d %H:%M:%S UTC") ${color}$(printf "[%9s]" "${log_level}")${color_reset} ${log_line}" 1>&2
    done <<<"${@:-}"
}
function fatal() {
    _log fatal "${@}"
    exit 1
}
function alert() {
    [[ "${LOG_LEVEL:-0}" -ge 1 ]] && _log alert "${@}"
    true
}
function critical() {
    [[ "${LOG_LEVEL:-0}" -ge 2 ]] && _log critical "${@}"
    true
}
function error() {
    [[ "${LOG_LEVEL:-0}" -ge 3 ]] && _log error "${@}"
    exit 1
}
function warn() {
    [[ "${LOG_LEVEL:-0}" -ge 4 ]] && _log warn "${@}"
    true
}
function notice() {
    [[ "${LOG_LEVEL:-0}" -ge 5 ]] && _log notice "${@}"
    true
}
function info() {
    [[ "${LOG_LEVEL:-0}" -ge 6 ]] && _log info "${@}"
    true
}
function debug() {
    [[ "${LOG_LEVEL:-0}" -ge 7 ]] && _log debug "${@}"
    true
}
function _exit() {
    _log fatal "script finished with errors."
}
trap _exit ERR

function define() { IFS='\n' read -r -d '' ${1} || true; }
function check_return_status() {
    if [ $? -ne 0 ]; then
        exit 1
    fi
}
function sqlcmd() {
    if ! [ -x "$(command -v sqlplus)" ]; then
        error 'could not find sqlplus command.'
    fi
    local sqlcmd_result
    local sqlplus_defaults
    local connect_info=$1
    sqlplus_defaults="$(echo -ne "set timing off \n set time off \n set echo off \n set showmode off \n set embedded on \n set verify off \n set feedback off \n set heading  off \n set pagesize 0 \n set linesize 32767 \n set trim on \n set trimspool on \n set term on \n set serveroutput on \n")"
    if [ $# -eq 0 ]; then
        error "sqlcmd: argument missing"
    fi
    sql="${sqlplus_defaults}\n$(cat)"
    #set -e
    sqlcmd_result="$(echo -ne "${sql}" | (sqlplus -s ${connect_info}) 2>&1)"
    # Error handling
    local sqlcmd_status=$?
    if [ $sqlcmd_status -ne 0 ] || [ "$(echo "${sqlcmd_result}" | grep -E '(ORA-|SP2-)')" != "" ]; then
        error "sqlcmd: returned exit code $sqlcmd_status and text: $sqlcmd_result"
    fi
    echo "${sqlcmd_result}"
}