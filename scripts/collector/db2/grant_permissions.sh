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

script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

db_name=""
target_user=""
target_pass=""
super_user=""
super_pass=""
host_name=""
port="50000"

active_node_alias=""
target_connect_alias=""

function print_usage() {
  echo "==================================================================================="
  echo "Database Migration Assessment (DMA) - DB2 Privilege Provisioning Utility"
  echo "==================================================================================="
  echo "Usage:"
  echo "  $0 --database <dbname> --username <target_user> [--password <target_pass>] \\"
  echo "     [--superUser <admin_user> --superPassword <admin_pass>] [--host <host> --port <port>]"
  echo ""
  echo "Parameters:"
  echo "  --database, --databaseService   The target DB2 database name (Required)."
  echo "  --username, --targetUser        The assessment username to create/grant privileges to (Required)."
  echo "  --password, --targetPassword    Password for the assessment user (Optional)."
  echo "  --superUser, --adminUser        Administrative user (SECADM / DBADM / instance owner) (Optional)."
  echo "  --superPassword, --adminPassword Password for the administrative user (Optional)."
  echo "  --host, --hostName              DB2 server hostname or IP address (Optional for local connections)."
  echo "  --port                          DB2 server port (Default: 50000)."
  echo "  --help, -h                      Display this help message."
  echo "==================================================================================="
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --database|--databaseService|-d)
      db_name="$2"
      shift 2
      ;;
    --database=*|--databaseService=*)
      db_name="${1#*=}"
      shift
      ;;
    --username|--targetUser|-u)
      target_user="$2"
      shift 2
      ;;
    --username=*|--targetUser=*)
      target_user="${1#*=}"
      shift
      ;;
    --password|--targetPassword|-p)
      target_pass="$2"
      shift 2
      ;;
    --password=*|--targetPassword=*)
      target_pass="${1#*=}"
      shift
      ;;
    --superUser|--adminUser|-s)
      super_user="$2"
      shift 2
      ;;
    --superUser=*|--adminUser=*)
      super_user="${1#*=}"
      shift
      ;;
    --superPassword|--adminPassword|-w)
      super_pass="$2"
      shift 2
      ;;
    --superPassword=*|--adminPassword=*)
      super_pass="${1#*=}"
      shift
      ;;
    --host|--hostName)
      host_name="$2"
      shift 2
      ;;
    --host=*|--hostName=*)
      host_name="${1#*=}"
      shift
      ;;
    --port)
      port="$2"
      shift 2
      ;;
    --port=*)
      port="${1#*=}"
      shift
      ;;
    --help|-h)
      print_usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown parameter '$1'"
      print_usage
      exit 1
      ;;
  esac
done

if [[ -z "${db_name}" ]]; then
  echo "ERROR: --database is required."
  print_usage
  exit 1
fi

if [[ -z "${target_user}" ]]; then
  echo "ERROR: --username is required."
  print_usage
  exit 1
fi

if ! command -v db2 &> /dev/null; then
  echo "ERROR: 'db2' CLI command not found in PATH. Please source the DB2 environment (e.g. sqllib/db2profile) and retry."
  exit 1
fi

# Optional OS-level user creation on local Linux systems if running with root privileges
if [[ -z "${host_name}" || "${host_name}" == "localhost" || "${host_name}" == "127.0.0.1" ]]; then
  if ! id "${target_user}" &>/dev/null; then
    if [[ $(id -u) -eq 0 ]] || sudo -n true 2>/dev/null; then
      echo "Creating local OS user '${target_user}'..."
      if [[ $(id -u) -eq 0 ]]; then
        useradd -m -s /bin/bash "${target_user}" 2>/dev/null
        if [[ -n "${target_pass}" ]] && command -v chpasswd &>/dev/null; then
          echo "${target_user}:${target_pass}" | chpasswd 2>/dev/null
        fi
      else
        sudo useradd -m -s /bin/bash "${target_user}" 2>/dev/null
        if [[ -n "${target_pass}" ]] && command -v chpasswd &>/dev/null; then
          echo "${target_user}:${target_pass}" | sudo chpasswd 2>/dev/null
        fi
      fi
    else
      echo "Note: Ensure OS user '${target_user}' exists on the DB2 host for authentication."
    fi
  fi
fi

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

# Dynamic Node / DB Cataloging for remote host connections
function catalog_remote_db() {
  target_connect_alias="${db_name}"
  active_node_alias=""

  if is_db_cataloged "${db_name}"; then
    echo "Database '${db_name}' is already cataloged locally. Using existing catalog entry."
    return 0
  fi

  if [[ -n "${host_name}" && "${host_name}" != "localhost" && "${host_name}" != "127.0.0.1" ]]; then
    local node_suffix=$(( (RANDOM % 9000) + 1000 ))
    local node_alias="N${node_suffix}"
    local db_alias="D${node_suffix}"
    
    echo "Cataloging remote node ${node_alias} (${host_name}:${port})..."
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
    
    echo "Cataloging remote database ${db_name} as alias ${db_alias}..."
    local db_out
    db_out=$(db2 "catalog database ${db_name} as ${db_alias} at node ${node_alias}" 2>&1)
    local db_ret=$?
    if [[ ${db_ret} -ne 0 ]] || echo "${db_out}" | grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC])'; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "[CATALOG_ERROR] Failed to catalog database '${db_name}' as alias '${db_alias}'."
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
    if [[ -n "${target_connect_alias}" && "${target_connect_alias}" != "${db_name}" ]]; then
      db2 "uncatalog database ${target_connect_alias}" > /dev/null 2>&1
    fi
    db2 "uncatalog node ${active_node_alias}" > /dev/null 2>&1
    db2 "terminate" > /dev/null 2>&1
  fi
}

catalog_remote_db
trap uncatalog_remote_db EXIT

echo "Connecting to DB2 database '${db_name}' as administrative user '${super_user:-CURRENT_USER}'..."

batch_file="${script_dir}/sql/setup/tmp_batch_$$.sql"
{
  if [[ -n "${super_user}" && -n "${super_pass}" ]]; then
    echo "connect to ${target_connect_alias} user ${super_user} using ${super_pass};"
  elif [[ -n "${super_user}" ]]; then
    echo "connect to ${target_connect_alias} user ${super_user};"
  else
    echo "connect to ${target_connect_alias};"
  fi
  sed "s/<USERNAME>/${target_user}/g" "${script_dir}/sql/setup/grant_permissions.sql"
  echo ""
  echo "terminate;"
} > "${batch_file}"

grant_output=$(db2 +p -tvf "${batch_file}" 2>&1)
grant_retval=$?
rm -f "${batch_file}"

echo "${grant_output}"

if echo "${grant_output}" | grep -E -q '(SQL[0-9]{4,5}[NEC]|DB2[0-9]{4,5}[NEC])'; then
  echo ""
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo "WARNING: One or more grant statements encountered errors."
  echo "Please review the SQL output above."
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  exit 1
else
  echo ""
  echo "==================================================================================="
  echo "SUCCESS: Assessment permissions successfully granted to user '${target_user}' on database '${db_name}'."
  echo "==================================================================================="
  exit 0
fi
