#!/usr/bin/env bash
# Copyright 2024 Google LLC
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

dma_version="6.0.0"
extractor_version="db2_collector_6.0.0"
database_type="db2"

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source "${script_dir}/dma_print_pass_fail.sh"

function init_variables() {
  output_dir="${script_dir}/output"
  log_dir="${script_dir}/log"
  sql_dir="${script_dir}/sql"
  
  mkdir -p "${output_dir}" "${log_dir}"
  
  export LC_ALL=C
  export LANG=C.UTF-8
  
  case "$(uname)" in
    "Solaris"|"SunOS" )
      sed_cmd="sed"
      grep_cmd="/usr/bin/ggrep"
      awk_cmd="/usr/xpg4/bin/awk"
      md5_cmd="csum -h MD5"
      ;;
    "AIX" )
      sed_cmd="sed"
      grep_cmd="grep"
      awk_cmd="/usr/bin/awk"
      md5_cmd="csum -h MD5"
      ;;
    "Darwin" )
      sed_cmd="sed -E"
      grep_cmd="grep"
      awk_cmd="awk"
      md5_cmd="md5 -q"
      ;;
    * )
      sed_cmd="sed -r"
      grep_cmd="grep"
      awk_cmd="awk"
      md5_cmd="md5sum"
      ;;
  esac
}

function print_usage() {
  echo "Usage:"
  echo "  $0 --database <dbname> --user <username> --password <password> [--host <host> --port <port>] [options]"
  echo ""
  echo "Parameters:"
  echo "  --database, --databaseService   The DB2 database name to assess (Required)."
  echo "  --user, --collectionUserName    The database user with assessment privileges (Required)."
  echo "  --password, --collectionUserPass The database user password (Required)."
  echo "  --host, --hostName              DB2 server hostname or IP address (Optional for local connections)."
  echo "  --port                          DB2 server port (Default: 50000)."
  echo "  --connectionStr                 Alternative connection string in user/pass@host:port/dbname format."
  echo "  --manualUniqueId                Optional customer tag to identify the collection."
  echo "  --vmUser                        OS username for host hardware stats discovery."
  echo "  --help, -h                      Display this help message."
  echo ""
}

function parse_parameters() {
  port="50000"
  manual_unique_id="NA"
  host_name=""
  database_service=""
  collection_user_name=""
  collection_user_pass=""
  vm_user=""
  
  while (( "$#" )); do
    case "$1" in
      --database|--databaseService) database_service="$2"; shift 2 ;;
      --user|--collectionUserName) collection_user_name="$2"; shift 2 ;;
      --password|--collectionUserPass) collection_user_pass="$2"; shift 2 ;;
      --host|--hostName) host_name="$2"; shift 2 ;;
      --port) port="$2"; shift 2 ;;
      --connectionStr) connection_string="$2"; shift 2 ;;
      --manualUniqueId) manual_unique_id="$2"; shift 2 ;;
      --vmUser) vm_user="$2"; shift 2 ;;
      --help|-h) print_usage; exit 0 ;;
      *) echo "Unknown parameter: $1"; print_usage; exit 1 ;;
    esac
  done

  if [[ -n "${connection_string}" ]]; then
    collection_user_name=$(echo "${connection_string}" | cut -d '/' -f 1)
    collection_user_pass=$(echo "${connection_string}" | cut -d '/' -f 2 | cut -d '@' -f 1)
    local host_and_port=$(echo "${connection_string}" | cut -d '/' -f 4)
    host_name=$(echo "${host_and_port}" | cut -d ':' -f 1)
    port=$(echo "${host_and_port}" | cut -d ':' -f 2)
    database_service=$(echo "${connection_string}" | cut -d '/' -f 5)
  fi

  if [[ -z "${database_service}" || -z "${collection_user_name}" || -z "${collection_user_pass}" ]]; then
    echo "ERROR: Database name, username, and password are required."
    print_usage
    exit 1
  fi
}

function check_dependencies() {
  echo "Stage 1: Checking operating system dependencies..."
  local deps=("db2" "grep" "sed" "awk" "cut" "tr" "date" "iconv" "wc" "tar")
  local missing=()
  for cmd in "${deps[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
      missing+=("${cmd}")
    fi
  done

  if ! command -v "md5sum" &> /dev/null && ! command -v "md5" &> /dev/null && ! command -v "csum" &> /dev/null; then
    missing+=("md5sum/md5/csum")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "[OS_DEPENDENCY_ERROR] Missing required operating system command(s): ${missing[*]}"
    echo "Please ensure the required utilities are installed and available in your PATH."
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 1
  fi
  echo "Stage 1: OS dependencies verified successfully."
}

function is_db_cataloged() {
  local target="$1"
  local target_upper
  target_upper=$(echo "${target}" | tr '[:lower:]' '[:upper:]')
  
  local catalog_list
  catalog_list=$(db2 list database directory 2>/dev/null | tr '[:lower:]' '[:upper:]')
  if echo "${catalog_list}" | grep -E -q "DATABASE[[:space:]]+(ALIAS|NAME)[[:space:]]*=[[:space:]]*${target_upper}([[:space:]]|$)"; then
    return 0
  else
    return 1
  fi
}

function catalog_remote_db() {
  target_connect_alias="${database_service}"
  active_node_alias=""

  if is_db_cataloged "${database_service}"; then
    echo "Database '${database_service}' is already cataloged locally. Using existing catalog entry."
    return 0
  fi

  if [[ -n "${host_name}" && "${host_name}" != "localhost" && "${host_name}" != "127.0.0.1" ]]; then
    local node_suffix=$(( (RANDOM % 9000) + 1000 ))
    local node_alias="N${node_suffix}"
    local db_alias="D${node_suffix}"
    
    echo "Cataloging remote DB2 node ${host_name}:${port} as ${node_alias}..."
    local node_out
    node_out=$(db2 "catalog tcpip node ${node_alias} remote ${host_name} server ${port}" 2>&1)
    local node_ret=$?
    if [[ ${node_ret} -ne 0 ]] || echo "${node_out}" | grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC])'; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "[CATALOG_ERROR] Failed to catalog remote DB2 node '${node_alias}' (${host_name}:${port})."
      echo "Output: ${node_out}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      exit 255
    fi
    active_node_alias="${node_alias}"
    
    echo "Cataloging database '${database_service}' as alias '${db_alias}' at node '${node_alias}'..."
    local db_out
    db_out=$(db2 "catalog database ${database_service} as ${db_alias} at node ${node_alias}" 2>&1)
    local db_ret=$?
    if [[ ${db_ret} -ne 0 ]] || echo "${db_out}" | grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC])'; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "[CATALOG_ERROR] Failed to catalog database '${database_service}' as alias '${db_alias}'."
      echo "Output: ${db_out}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      uncatalog_remote_db
      exit 255
    fi
    db2 "terminate" > /dev/null 2>&1
    
    target_connect_alias="${db_alias}"
  fi
}

function uncatalog_remote_db() {
  if [[ -n "${active_node_alias}" ]]; then
    db2 "connect reset" > /dev/null 2>&1
    if [[ -n "${target_connect_alias}" && "${target_connect_alias}" != "${database_service}" ]]; then
      db2 "uncatalog database ${target_connect_alias}" > /dev/null 2>&1
    fi
    db2 "uncatalog node ${active_node_alias}" > /dev/null 2>&1
    db2 "terminate" > /dev/null 2>&1
  fi
}

function check_db_connection() {
  echo "Stage 2: Verifying database connectivity..."
  local conn_out
  conn_out=$(db2 "connect to ${target_connect_alias} user ${collection_user_name} using ${collection_user_pass}" 2>&1)
  local retcd=$?
  
  if [[ $retcd -ne 0 ]] || echo "${conn_out}" | grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC])'; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "[DATABASE_CONNECTION_ERROR] Failed to connect to DB2 database '${database_service}'."
    echo "Connection Output:"
    echo "${conn_out}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  fi
  echo "Stage 2: Database connection established successfully."
}

function run_db2_query() {
  local query="$1"
  local tmp_qry="${sql_dir}/tmp_qry_$$.sql"
  {
    echo "connect to ${target_connect_alias} user ${collection_user_name} using ${collection_user_pass};"
    echo "${query};"
    echo "terminate;"
  } > "${tmp_qry}"

  db2 +p -tx -f "${tmp_qry}" 2>&1 | \
    sed -e '/Database Connection Information/d' \
        -e '/Database server/d' \
        -e '/SQL authorization ID/d' \
        -e '/Local database alias/d' \
        -e '/DB20000I/d' \
        -e '/record(s) selected/d' \
        -e '/command completed/d' \
        -e '/^[[:space:]]*-[[:space:]]*-*[[:space:]]*$/d' \
        -e '/^$/d' \
        -e 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        -e 's/[[:space:]]*|[[:space:]]*/|/g'

  rm -f "${tmp_qry}"
}

function run_db2_file() {
  local sql_file="$1"
  local log_file="$2"
  local tmp_batch="${sql_dir}/tmp_batch_$$.sql"

  {
    echo "connect to ${target_connect_alias} user ${collection_user_name} using ${collection_user_pass};"
    cat "${sql_file}"
    echo ""
    echo "terminate;"
  } > "${tmp_batch}"

  local raw_output
  raw_output=$(db2 +p -tx -f "${tmp_batch}" 2>&1)
  rm -f "${tmp_batch}"

  # Capture and log DB2 errors (SQL#####N/E/C, DB2#####N/E/C, SQLSTATE) to the error log
  if echo "${raw_output}" | grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC]|SQLSTATE=)'; then
    echo "===================================================================" >> "${log_file}"
    echo "ERROR executing $(basename "${sql_file}") at $(date):" >> "${log_file}"
    echo "${raw_output}" | grep -E '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC]|SQLSTATE=)' >> "${log_file}"
    echo "===================================================================" >> "${log_file}"
  fi

  # Filter out banners, status codes, errors, dashes, and empty lines to emit clean CSV rows
  echo "${raw_output}" | \
    sed -e '/Database Connection Information/d' \
        -e '/Database server/d' \
        -e '/SQL authorization ID/d' \
        -e '/Local database alias/d' \
        -e '/DB20000I/d' \
        -e '/record(s) selected/d' \
        -e '/command completed/d' \
        -e '/SQL[0-9]\{4,5\}[NEC]/d' \
        -e '/DB2[0-9]\{4,5\}[NEC]/d' \
        -e '/SQLSTATE=/d' \
        -e '/^[[:space:]]*-[[:space:]]*-*[[:space:]]*$/d' \
        -e '/^$/d' \
        -e 's/^[[:space:]]*//;s/[[:space:]]*$//' \
        -e 's/[[:space:]]*|[[:space:]]*/|/g'
}

function check_db_version_and_platform() {
  echo "Stage 3: Verifying DB2 engine version and platform..."
  local plat_out
  plat_out=$(run_db2_query "SELECT CASE WHEN service_level LIKE 'DB2/z%' OR service_level LIKE 'DSN%' THEN 'zos' ELSE 'luw' END FROM TABLE(sysproc.env_get_inst_info()) FETCH FIRST 1 ROWS ONLY")
  
  plat_out=$(echo "${plat_out}" | tr -d '[:space:]')
  if [[ "${plat_out}" == "zos" ]]; then
    db_platform="zos"
  else
    db_platform="luw"
  fi

  local ver_out
  ver_out=$(run_db2_query "SELECT service_level FROM TABLE(sysproc.env_get_inst_info()) FETCH FIRST 1 ROWS ONLY")
  ver_out=$(echo "${ver_out}" | tr -d '\n\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  
  if [[ -z "${ver_out}" || "${ver_out}" == *"SQL1024N"* || "${ver_out}" == *"SQL0"* ]]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "[DATABASE_VERSION_ERROR] Failed to retrieve DB2 version information."
    echo "Output: ${ver_out}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  fi

  local plat_upper
  plat_upper=$(echo "${db_platform}" | tr '[:lower:]' '[:upper:]')
  echo "Detected DB2 Platform: ${plat_upper}"
  echo "Detected DB2 Version: ${ver_out}"
  echo "Stage 3: Version and platform verified."
}

function check_permissions_preflight() {
  echo "Stage 4: Checking database permissions against permissions.csv..."
  local perm_file="${script_dir}/sql/setup/permissions.csv"
  if [[ ! -f "${perm_file}" ]]; then
    echo "Warning: permissions.csv not found at ${perm_file}, skipping pre-flight permissions check."
    return 0
  fi

  local probe_out
  probe_out=$(run_db2_query "SELECT count(1) FROM SYSCAT.TABLES FETCH FIRST 1 ROWS ONLY")
  local retcd=$?

  if [[ $retcd -ne 0 ]] || echo "${probe_out}" | grep -E -q '(SQL0551N|SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC])'; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "[INSUFFICIENT_PERMISSIONS_ERROR] The assessment user '${collection_user_name}' lacks required database privileges."
    echo "Probe Output:"
    echo "${probe_out}"
    echo ""
    echo "REMEDIATION:"
    echo "An administrator must grant permissions by running:"
    echo "  ./grant_permissions.sh --username ${collection_user_name} --database ${database_service}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  fi
  echo "Stage 4: Database permissions pre-flight check passed."
}

function execute_collection() {
  local timestamp=$(date +"%Y%m%d%H%M%S")
  local host_ident="${host_name:-$(hostname)}"
  v_tagbase="${host_ident}_${database_service}_${timestamp}"
  pkey="${host_ident}_${database_service}_${timestamp}"
  
  echo "Generating DMA_SOURCE_ID..."
  dma_source_id=$(run_db2_file "${sql_dir}/init.sql" "${log_dir}/init_${v_tagbase}.log" | tr -d '[:space:]')
  if [[ -z "${dma_source_id}" || "${dma_source_id}" == *"SQL"* ]]; then
    dma_source_id="${host_ident}_${database_service}"
  fi
  
  echo "Target Collection Tag: ${v_tagbase}"
  echo "DMA Source ID: ${dma_source_id}"
  echo ""

  # Category 1: Host Hardware Specs
  echo "Extracting Category 1: Host machine specs..."
  "${script_dir}/db-machine-specs.sh" "${host_ident}" "${vm_user}" "${pkey}" "${dma_source_id}" "${manual_unique_id}" "${output_dir}/opdb__db2_db_machine_specs_${v_tagbase}.csv"

  local extract_path="${sql_dir}/extracts/${db_platform}"
  local extracts=(
    "db_instances"
    "databases"
    "db_configurations"
    "schema_objects"
    "performance_metrics"
    "features"
    "eoj"
  )

  for ext in "${extracts[@]}"; do
    echo "Extracting ${ext}..."
    local src_sql="${extract_path}/${ext}.sql"
    local tmp_sql="${sql_dir}/tmp_${ext}.sql"
    local out_csv="${output_dir}/opdb__db2_${ext}_${v_tagbase}.csv"
    local hdr_file="${sql_dir}/headers/${ext}.header"

    if [[ -f "${src_sql}" ]]; then
      sed "s/@PKEY@/${pkey}/g; s/@DMA_SOURCE_ID@/${dma_source_id}/g; s/@DMA_MANUAL_ID@/${manual_unique_id}/g" "${src_sql}" > "${tmp_sql}"
      
      # Inject Header
      if [[ -f "${hdr_file}" ]]; then
        cat "${hdr_file}" > "${out_csv}"
      fi
      
      # Execute query and append clean data rows
      run_db2_file "${tmp_sql}" "${log_dir}/db2_errors_${v_tagbase}.log" >> "${out_csv}"
      
      rm -f "${tmp_sql}"
    else
      echo "Warning: Extract script not found: ${src_sql}"
    fi
  done
}

function package_and_validate() {
  echo ""
  echo "Sanitizing and packaging collection..."
  local manifest_file="${output_dir}/opdb__db2_manifest_${v_tagbase}.txt"
  rm -f "${manifest_file}"

  local error_found=0
  local eoj_file="${output_dir}/opdb__db2_eoj_${v_tagbase}.csv"
  if [[ ! -f "${eoj_file}" ]] || ! grep -q "END_OF_DMA_COLLECTION" "${eoj_file}"; then
    echo "Warning: EOJ marker missing or incomplete."
    error_found=1
  fi

  local error_log="${log_dir}/db2_errors_${v_tagbase}.log"
  local output_error_log="${output_dir}/opdb__db2_errors_${v_tagbase}.log"

  # Check for errors in the execution error log or in any generated CSV file
  if [[ -f "${error_log}" && -s "${error_log}" ]]; then
    if grep -E '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC]|ERR)' "${error_log}" > /dev/null 2>&1; then
      echo "Warning: Database errors detected in error log."
      error_found=1
    fi
  fi

  cd "${output_dir}"
  if grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC]|SQLSTATE=)' opdb__db2_*_${v_tagbase}.csv 2>/dev/null; then
    echo "Warning: Database errors detected in extract CSV files."
    error_found=1
  fi

  # If errors found, copy error log to output directory so it is included in the package per PRD
  if [[ ${error_found} -eq 1 ]]; then
    if [[ -f "${error_log}" ]]; then
      cp "${error_log}" "${output_error_log}"
    else
      echo "DMA DB2 collection failed: EOJ marker missing or query execution error." > "${output_error_log}"
    fi
  fi

  # Create manifest
  for f in opdb__db2_*_${v_tagbase}.csv opdb__db2_errors_${v_tagbase}.log; do
    if [[ -f "$f" ]]; then
      local chk
      chk=$(${md5_cmd} "$f" | cut -d ' ' -f 1)
      echo "db2|${chk}|$f" >> "${manifest_file}"
    fi
  done

  local archive_name="opdb_db2__${v_tagbase}.zip"
  if [[ ${error_found} -eq 1 ]]; then
    archive_name="opdb_db2__${v_tagbase}_ERROR.zip"
  fi

  local output_archive="${output_dir}/${archive_name}"

  if command -v zip &> /dev/null; then
    zip -q "${archive_name}" opdb__db2_*_${v_tagbase}.csv opdb__db2_manifest_${v_tagbase}.txt opdb__db2_errors_${v_tagbase}.log 2>/dev/null
  else
    archive_name="opdb_db2__${v_tagbase}.tar.gz"
    output_archive="${output_dir}/${archive_name}"
    tar -czf "${archive_name}" opdb__db2_*_${v_tagbase}.csv opdb__db2_manifest_${v_tagbase}.txt opdb__db2_errors_${v_tagbase}.log 2>/dev/null
  fi

  # Clean up extracted CSV files, error log copy, and manifest once archive is created
  if [[ -f "${output_archive}" ]]; then
    rm -f opdb__db2_*_${v_tagbase}.csv opdb__db2_manifest_${v_tagbase}.txt opdb__db2_errors_${v_tagbase}.log
  fi

  echo "==================================================================================="
  if [[ ${error_found} -eq 0 ]]; then
    print_complete
    echo "DB2 Assessment Collection Completed Successfully."
    echo "Output Archive: ${output_archive}"
  else
    print_warning
    echo "DB2 Assessment Collection Completed with Warnings/Errors."
    echo "Output Archive: ${output_archive}"
    if [[ -f "${error_log}" && -s "${error_log}" ]]; then
      echo ""
      echo "Captured Errors:"
      cat "${error_log}"
      echo ""
    fi
    echo "Check error log in: ${error_log}"
  fi
  echo "==================================================================================="
}

function main() {
  echo "==================================================================================="
  echo "Database Migration Assessment (DMA) - IBM DB2 Assessment Collector v${dma_version}"
  echo "==================================================================================="
  
  init_variables
  parse_parameters "$@"
  check_dependencies
  
  catalog_remote_db
  trap uncatalog_remote_db EXIT
  
  check_db_connection
  check_db_version_and_platform
  check_permissions_preflight
  
  execute_collection
  package_and_validate
}

main "$@"
