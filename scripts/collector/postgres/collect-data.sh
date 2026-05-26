#!/bin/bash

# Copyright 2026 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

OP_VERSION="latest"
dbmajor=""

LOCALE=$(echo "${LANG:-C}" | cut -d '.' -f 1)
export LANG=C
export LANG="${LOCALE}.UTF-8"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
SQLCMD="psql"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/postgres_collector_output}"
TMP_DIR="${SCRIPT_DIR}/tmp"
LOG_DIR="${SCRIPT_DIR}/log"
SQL_DIR="${SCRIPT_DIR}/sql"

DBTYPE="postgres"

GREP="$(command -v grep || true)"
SED="$(command -v sed || true)"
MD5SUM="$(command -v md5sum || true)"
MD5COL=1
ZIP=""
GZIP=""

DMA_RECURSION=0
MANUAL_ID=""

if [[ -z "${GREP}" ]]; then
  GREP="grep"
fi
if [[ -z "${SED}" ]]; then
  SED="sed"
fi
if [[ -z "${MD5SUM}" ]]; then
  MD5SUM="md5sum"
fi

if [[ "$(uname)" == "SunOS" ]]; then
  GREP="/usr/xpg4/bin/grep"
  SED="/usr/xpg4/bin/sed"
fi

if [[ "$(uname)" == "HP-UX" ]]; then
  if [[ -f /usr/local/bin/md5 ]]; then
    MD5SUM="/usr/local/bin/md5"
    MD5COL=4
  fi
fi

ZIP="$(command -v zip || true)"
if [[ -z "${ZIP}" ]]; then
  GZIP="$(command -v gzip || true)"
fi

# Directories will be created after command line parameters are parsed

check_platform() {
  local db_type="$1"

  if [[ "${db_type}" == "postgres" ]]; then
    SQLCMD="psql"
  fi

  if uname -a | "${GREP}" -qi microsoft; then
    SQL_DIR="$(wslpath -a -w "${SCRIPT_DIR}")/sql"
    SQLOUTPUT_DIR="$(wslpath -a -w "${SQLOUTPUT_DIR}")"
  fi

  if uname -a | "${GREP}" -qi cygwin; then
    SQL_DIR="$(cygpath -w "${SCRIPT_DIR}")/sql"
    SQLOUTPUT_DIR="$(cygpath -w "${SQLOUTPUT_DIR}")"
    SQLCMD="${SQLCMD}.exe"
  fi
}

check_version_pg() {
  local user="$1"
  local pass="$2"
  local host="$3"
  local port="$4"
  local db="$5"
  local op_version="$6"

  if ! command -v "${SQLCMD}" >/dev/null 2>&1; then
    echo "Could not find ${SQLCMD} command. Source in environment and try again"
    echo "Exiting..."
    exit 1
  fi

  local db_version retcd
  set +e
  db_version=$(PGPASSWORD="${pass}" "${SQLCMD}" -X --user="${user}" -h "${host}" -w -p "${port}" -d "${db}" -t --no-align 2>&1 <<EOF
SELECT current_setting('server_version_num');
EOF
)
  retcd=$?
  if [[ ${retcd} -ne 0 ]]; then
    echo "Error connecting to the target database ${user}@${host}:${port}/${db}."
    echo "Connection attempt returned : ${db_version}"
    return "${retcd}"
  fi
  set -e

  echo "DMAFILETAG~${db_version}|${db_version}_${op_version}_${host}-${port}_${db}_${db}_$(date +%y%m%d%H%M%S)"
}

execute_op_pg() {
  local user="$1"
  local pass="$2"
  local host="$3"
  local port="$4"
  local db="$5"
  local op_version="$6"
  local file_tag="$7"
  local manual_id="$8"
  local pg_version="$9"
  local all_dbs="${10}"

  if ! command -v "${SQLCMD}" >/dev/null 2>&1; then
    echo "Could not find ${SQLCMD} command. Source in environment and try again"
    echo "Exiting..."
    exit 1
  fi

  local dma_source_id retcd
  set +e
  dma_source_id=$(PGPASSWORD="${pass}" "${SQLCMD}" -X --user="${user}" -h "${host}" -w -p "${port}" -d "${db}" -t --no-align <<EOF
SELECT system_identifier FROM pg_control_system();
EOF
)
  retcd=$?
  set -e
  if [[ ${retcd} -ne 0 ]]; then
    dma_source_id="NA"
  fi

  if [[ -z "${manual_id}" ]]; then
    manual_id="NA"
  fi

  if [[ -z "${dma_source_id}" ]]; then
    dma_source_id="NA"
  fi

  local specs_out="${OUTPUT_DIR}/opdb__pg_db_machine_specs_${host}.csv"
  if [[ ! -f "${specs_out}" ]]; then
    if [[ "${COLLECT_OS_SPECS}" == "true" || "${COLLECT_OS_SPECS}" == "Y" ]]; then
      # Verify vmUserName is provided for remote hosts to prevent hung SSH loops
      if [[ "${host}" != "127.0.0.1" && "${host}" != "localhost" && "${host}" != "0.0.0.0" ]]; then
        if [[ -z "${vmUserName}" ]]; then
          echo "Warning: vmUserName is not set for remote host '${host}'. Skipping optional OS specs collection..." >&2
          ssh_retval=0
        fi
      fi
      
      if [[ -z "${ssh_retval:-}" ]]; then
        echo "Running optional OS specs collector..."
        set +e
        ./db-machine-specs.sh "${host}" "${vmUserName}" "${file_tag}" "${dma_source_id}" "${manual_id}" "${specs_out}" "${extraSSHArgs[@]}"
        local ssh_retval=$?
        set -e
        if [[ ${ssh_retval} -ne 0 ]]; then
          echo "Warning: Optional OS metric collection failed (exit code: ${ssh_retval}). Continuing database collection..." >&2
          rm -f "${specs_out}"
        fi
      fi
    else
      echo "Optional OS metric collection is disabled (COLLECT_OS_SPECS=false). Skipping..."
    fi
  fi

  if [[ "${all_dbs}" == "Y" ]]; then
    local oldifs="${IFS}"
    IFS=$'\n'
    local dblist
    set +e
    dblist=$(PGPASSWORD="${pass}" "${SQLCMD}" --user="${user}" -h "${host}" -w -p "${port}" -d "${db}" -t --no-align <<EOF
SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' ORDER BY datname;
EOF
)
    retcd=$?
    set -e
    if [[ ${retcd} -ne 0 ]]; then
      echo "Error listing databases for ${user}@${host}:${port}/${db}."
      echo "${dblist}"
      return "${retcd}"
    fi

    for db in ${dblist}; do
      export DMA_RECURSION=1
      IFS="${oldifs}"
      ./collect-data.sh --connectionStr "${user}/${pass}@//${host}:${port}/${db}" --manualUniqueId "${manual_id}" --specsPath "${specs_out}" --allDbs N
    done
    IFS="${oldifs}"
    if [[ -f "${specs_out}" ]]; then
      rm "${specs_out}"
    fi
    exit
  fi

  export PGPASSWORD="${pass}"
  set +e
  "${SQLCMD}" -X --user="${user}" -d "${db}" -h "${host}" -w -p "${port}" -A -t -F, -v ON_ERROR_STOP=1 --echo-errors 2>"${OUTPUT_DIR}/opdb__stderr_${file_tag}.log" <<EOF
\set VTAG ${file_tag}
\set PKEY '\'${file_tag}\''
\set DMA_SOURCE_ID '\'${dma_source_id}\''
\set DMA_MANUAL_ID '\'${manual_id}\''
\set VPGVERSION ${pg_version}
\i sql/op_collect.sql
EOF
  retcd=$?
  return "${retcd}"
}

create_error_log() {
  local file_tag="$1"
  echo "Checking for errors..."
  : > "${LOG_DIR}/opdb__${file_tag}_errors.log"
  if [[ "${DBTYPE}" == "postgres" ]]; then
    if [[ -f "${OUTPUT_DIR}/opdb__stderr_${file_tag}.log" ]]; then
      "${GREP}" -i -E 'ERROR:' "${OUTPUT_DIR}/opdb__stderr_${file_tag}.log" >> "${LOG_DIR}/opdb__${file_tag}_errors.log" || true
    fi
  fi
  if [[ ! -f "${LOG_DIR}/opdb__${file_tag}_errors.log" ]]; then
    echo "Error creating error log.  Exiting..."
    return 1
  fi
}

cleanup_op_output() {
  local file_tag="$1"
  echo "Preparing files for compression."
  # Native psql formatting (-A -t -F,) generates clean CSVs directly.
  # Brittle sed cleanup is bypassed.
}

compress_op_files() {
  local file_tag="$1"
  local host_name="$2"
  local is_failure="${3:-0}"
  local err_tag=""
  local retval=0

  echo ""
  echo "Archiving output files with tag ${file_tag}"
  local current_working_dir
  current_working_dir="$(pwd)"
  if [[ -f "${LOG_DIR}/opdb__${file_tag}_errors.log" ]]; then
    cp "${LOG_DIR}/opdb__${file_tag}_errors.log" "${OUTPUT_DIR}/opdb__${file_tag}_errors.log"
  fi
  if [[ -f VERSION.txt ]]; then
    cp VERSION.txt "${OUTPUT_DIR}/opdb__${file_tag}_version.txt"
  else
    echo "No Version file found" > "${OUTPUT_DIR}/opdb__${file_tag}_version.txt"
  fi
  if [[ -f "${OUTPUT_DIR}/opdb__pg_db_machine_specs_${host_name}.csv" ]]; then
    cp "${OUTPUT_DIR}/opdb__pg_db_machine_specs_${host_name}.csv" "${OUTPUT_DIR}/opdb__pg_db_machine_specs_${file_tag}.csv"
  fi
  if [[ ${DMA_RECURSION} -ne 1 ]] && [[ -f "${OUTPUT_DIR}/opdb__pg_db_machine_specs_${host_name}.csv" ]]; then
    rm "${OUTPUT_DIR}/opdb__pg_db_machine_specs_${host_name}.csv"
  fi

  local errcnt=0
  if [[ -f "${OUTPUT_DIR}/opdb__${file_tag}_errors.log" ]]; then
    errcnt=$(wc -l < "${OUTPUT_DIR}/opdb__${file_tag}_errors.log")
  fi

  if [[ ${errcnt} -ne 0 ]] || [[ "${is_failure}" -ne 0 ]]; then
    err_tag="_ERROR"
    retval=1
    echo "Errors reported during collection:"
    if [[ -f "${OUTPUT_DIR}/opdb__${file_tag}_errors.log" ]]; then
      cat "${OUTPUT_DIR}/opdb__${file_tag}_errors.log"
    fi
    echo " "
    echo "Please rerun the extract after correcting the error condition."
  fi

  local tarfile="opdb_${DBTYPE}_${DIAGPACKACCESS}__${file_tag}${err_tag}.tar"
  local zipfile="opdb_${DBTYPE}_${DIAGPACKACCESS}__${file_tag}${err_tag}.zip"

  locale > "${OUTPUT_DIR}/opdb__${file_tag}_locale.txt"

  echo "dbmajor = ${dbmajor}"  >> "${OUTPUT_DIR}/opdb__defines__${file_tag}.csv"
  echo "MANUAL_ID : " ${MANUAL_ID} >> "${OUTPUT_DIR}/opdb__defines__${file_tag}.csv"
  echo "ZIPFILE: " "${zipfile}" >> "${OUTPUT_DIR}/opdb__defines__${file_tag}.csv"

  cd "${OUTPUT_DIR}"
  if [[ -f "opdb__manifest__${file_tag}.txt" ]]; then
    rm "opdb__manifest__${file_tag}.txt"
  fi

  for file in $(ls -1 opdb*"${file_tag}".csv opdb*"${file_tag}"*.log opdb*"${file_tag}"*.txt); do
    local md5
    md5=$("${MD5SUM}" "${file}" | cut -d ' ' -f "${MD5COL}")
    echo "${DBTYPE}|${md5}|${file}"  >> "opdb__manifest__${file_tag}.txt"
  done

  if [[ -n "${ZIP}" ]]; then
    "${ZIP}" "${zipfile}" opdb*"${file_tag}".csv opdb*"${file_tag}"*.log opdb*"${file_tag}"*.txt
    OUTFILE="${zipfile}"
  else
    tar cvf "${tarfile}" opdb*"${file_tag}".csv opdb*"${file_tag}"*.log opdb*"${file_tag}"*.txt
    "${GZIP}" "${tarfile}"
    OUTFILE="${tarfile}.gz"
  fi

  if [[ -f "${OUTFILE}" ]]; then
    rm opdb*"${file_tag}".csv opdb*"${file_tag}"*.log opdb*"${file_tag}"*.txt
  fi

  cd "${current_working_dir}"
  echo ""
  echo "Step completed."
  echo ""
  return "${retval}"
}

get_version() {
  if [[ -f VERSION.txt ]]; then
    local githash
    githash=$(cut -d '(' -f 2 < VERSION.txt | tr -d ')')
    echo "${githash}"
  else
    echo "NONE"
  fi
}

print_extractor_version() {
  local version="$1"
  if [[ "${version}" == "NONE" ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "This appears to be an unsupported version of this code. "
    echo "Please download the latest stable version from "
    echo "https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-postgres.zip"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  else
    echo "Using release version ${version}"
  fi
}

print_usage() {
  echo " Usage:"
  echo "  Parameters"
  echo ""
  echo "  Connection definition must one of:"
  echo "      {"
  echo "        --connectionStr       Connection string formatted as {user}/{password}@//{db host}:{listener port}/{service name}"
  echo "       or"
  echo "        --hostName            Database server host name"
  echo "        --port                Database listener port"
  echo "        --databaseService     Database service name (Optional. Defaults to 'postgres'.)"
  echo "        --collectionUserName  Database user name."
  echo "        --collectionUserPass  Database password"
  echo "        --allDbs              Collect data for all databases (Y/N).  Optional. Defaults to 'Y'.  Set to N to collect for only the database service given."
  echo "      }"
  echo
  echo "  Additional Parameters:"
  echo "        --manualUniqueId      (Optional) A short string to be attached to this collection.  Use only when directed."
  echo
  echo "  VM collection definition (optional):"
  echo "        --vmUserName          Username on the VM the Database is running on."
  echo "                              Must be supplied to collect hardware configuration of the database server if"
  echo "                              the collection script is not run directly on the database server."
  echo "        --extraSSHArg         Extra args to be passed as is to ssh. Can be specified multiple times."
  echo
  echo " Example:"
  echo
  echo " To collect data for a single database:"
  echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} --allDbs N"
  echo " or"
  echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --allDbs N"
  echo
  echo " To collect data for all databases in the instance:"
  echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} "
  echo " or"
  echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}"
}

hostName="${PGHOST:-}"
port="${PGPORT:-}"
databaseService="${PGDATABASE:-postgres}"
collectionUserName="${PGUSER:-}"
collectionUserPass="${PGPASSWORD:-}"
statsSrc=""
connStr=""
manualUniqueId=""
vmUserName=""
extraSSHArgs=()
specsPath=""
allDbs="Y"

SQL_DIR="${SQL_DIR:-${SCRIPT_DIR}/sql}"
COLLECT_OS_SPECS="${COLLECT_OS_SPECS:-false}"

if [[ $(($# & 1)) == 1 ]]; then
  echo "Invalid number of parameters "
  print_usage
  exit 1
fi

while (($#)); do
  case "$1" in
    --hostName) hostName="${2}" ;;
    --port) port="${2}" ;;
    --databaseService) databaseService="${2}" ;;
    --collectionUserName) collectionUserName="${2}" ;;
    --collectionUserPass) collectionUserPass="${2}" ;;
    --connectionStr) connStr="${2}" ;;
    --manualUniqueId) manualUniqueId="${2}" ;;
    --vmUserName) vmUserName="${2}" ;;
    --extraSSHArg) extraSSHArgs+=("${2}") ;;
    --specsPath) specsPath="${2}" ;;
    --allDbs) allDbs="${2}" ;;
    --outputDir) OUTPUT_DIR="${2}" ;;
    *)
      echo "Unknown parameter ${1}"
      print_usage
      exit 1
      ;;
  esac
  shift 2
done

# Ensure dependent output variables are exported and directories created after parsing CLI flags
export OUTPUT_DIR
SQLOUTPUT_DIR="${OUTPUT_DIR}"; export SQLOUTPUT_DIR
mkdir -p "${LOG_DIR}" "${OUTPUT_DIR}"

DIAGPACKACCESS="postgres"

if [[ -n "${connStr}" ]]; then
  # Format: {user}/{password}@//{host}:{port}/{db} or {user}/{password}@{host}:{port}/{db}
  if [[ "${connStr}" == *@//* ]]; then
    cred_part="${connStr%@//*}"
    host_part="${connStr#*@//}"
  else
    cred_part="${connStr%@*}"
    host_part="${connStr#*@}"
  fi

  collectionUserName="${cred_part%%/*}"
  collectionUserPass="${cred_part#*/}"

  host_port="${host_part%%/*}"
  databaseService="${host_part#*/}"

  if [[ "${host_port}" == *:* ]]; then
    hostName="${host_port%%:*}"
    port="${host_port#*:}"
  else
    hostName="${host_port}"
    port="5432"
  fi
fi

if [[ -z "${hostName}" || -z "${collectionUserName}" || -z "${collectionUserPass}" ]]; then
  echo "Connection information incomplete. Please set PGHOST/PGUSER/PGPASSWORD, use --connectionStr, or pass explicit CLI flags."
  print_usage
  exit 1
fi

if [[ -z "${port}" ]]; then
  port="5432"
fi

if [[ "${allDbs}" != "Y" && "${allDbs}" != "N" ]]; then
  echo "Invalid value supplied for parameter allDbs.  Must be Y or N."
  print_usage
  exit 255
fi

if [[ -n "${manualUniqueId}" && "${manualUniqueId}" != "NA" ]]; then
  if command -v iconv >/dev/null 2>&1; then
    manualUniqueId=$(printf "%s" "${manualUniqueId}" | iconv -t ascii//TRANSLIT | "${SED}" -E -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
  else
    manualUniqueId=$(printf "%s" "${manualUniqueId}" | "${SED}" -E -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
  fi
else
  manualUniqueId="NA"
fi

check_platform "${DBTYPE}"

if ! command -v "${SQLCMD}" >/dev/null 2>&1; then
  echo "Error: Could not find '${SQLCMD}' client command in the system PATH."
  echo "Please ensure PostgreSQL client tools are installed and sourced in your environment."
  exit 1
fi

retval=0
sqlcmd_result=""
if [[ "${DBTYPE}" == "postgres" ]]; then
  set +e
  sqlcmd_result=$(check_version_pg "${collectionUserName}" "${collectionUserPass}" "${hostName}" "${port}" "${databaseService}" "${OP_VERSION}")
  retval=$?
  set -e
  if [[ ${retval} -ne 0 ]]; then
    echo " "
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Unable to connect to the target Postgres database.  Please verify the connection information and target database status."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  else
    sqlcmd_result=$(echo "${sqlcmd_result}" | "${GREP}" DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r')
  fi
fi

extractorVersion="$(get_version)"

echo ""
echo "==================================================================================="
echo "Database Migration Assessment Database Assessment Collector Version ${OP_VERSION}"
print_extractor_version "${extractorVersion}"
echo "==================================================================================="

if [[ ${retval} -eq 0 ]]; then
  if [[ "$(echo "${sqlcmd_result}" | "${GREP}" -E '(ORA-|SP2-|ERROR|FATAL)')" != "" ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database version check returned error ${sqlcmd_result}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Exiting...."
    exit 255
  fi

  echo "Your database version is $(echo "${sqlcmd_result}" | cut -d '|' -f1)"
  dbmajor=$(echo "${sqlcmd_result}" | cut -d '|' -f1 | cut -d '.' -f 1)
  V_TAG="$(echo "${sqlcmd_result}" | cut -d '|' -f2).csv"; export V_TAG

  if [[ "${DBTYPE}" == "postgres" ]]; then
    PGVER=$(echo "${dbmajor}" | cut -c 1-2)
    if [[ "${PGVER}" != "11" && "${PGVER}" != "12" && "${PGVER}" != "13" && "${PGVER}" != "17" ]]; then
      echo "Unassigned or legacy major version '${PGVER}' detected. Routing catalog queries to 'base' templates..."
      PGVER="base"
    fi
    set +e
    execute_op_pg "${collectionUserName}" "${collectionUserPass}" "${hostName}" "${port}" "${databaseService}" "${OP_VERSION}" "$(echo "${V_TAG}" | "${SED}" 's/.csv//g')" "${manualUniqueId}" "${PGVER}" "${allDbs}"
    retval=$?
    set -e
  fi

  # Move files to custom output directory if overridden
  if [[ "${OUTPUT_DIR}" != "${SCRIPT_DIR}/output" ]]; then
    if [[ -d "${SCRIPT_DIR}/output" ]]; then
      mv "${SCRIPT_DIR}/output"/opdb*"$(echo "${V_TAG}" | "${SED}" 's/.csv//g')"* "${OUTPUT_DIR}/" 2>/dev/null || true
    fi
  fi

  if [[ ${retval} -ne 0 ]]; then
    create_error_log "$(echo "${V_TAG}" | "${SED}" 's/.csv//g')"
    compress_op_files "$(echo "${V_TAG}" | "${SED}" 's/.csv//g')" "${hostName}" "1"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database Migration Assessment extract reported an error.  Please check the error log in directory ${LOG_DIR}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Exiting...."
    exit 255
  fi

  create_error_log "$(echo "${V_TAG}" | "${SED}" 's/.csv//g')"
  cleanup_op_output "$(echo "${V_TAG}" | "${SED}" 's/.csv//g')"
  if [[ $? -ne 0 ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database Migration Assessment data sanitation reported an error. Please check the error log in directory ${OUTPUT_DIR}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Exiting...."
    exit 255
  fi
  compress_op_files "$(echo "${V_TAG}" | "${SED}" 's/.csv//g')" "${hostName}"
  if [[ $? -ne 0 ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database Migration Assessment data file archive encountered a problem.  Exiting...."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  fi

  echo ""
  echo "==================================================================================="
  echo "Database Migration Assessment Database Assessment Collector completed."
  echo "Data collection located at ${OUTPUT_DIR}/${OUTFILE}"
  echo "==================================================================================="
  echo ""
  print_extractor_version "${extractorVersion}"
  exit 0
fi

echo "Error executing SQL*Plus"
exit 255