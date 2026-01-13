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

# Global variables and constants
dma_version="4.3.45"
collection_user_name=""
collection_user_pass=""
conn_str=""
connect_string=""
database_service=""
database_type=""
dbmajor=""
extra_ssh_args=()
host_name=""
log_dir=""
manual_unique_id=""
output_dir=""
port=""
script_dir=""
sql_cmd=""
sql_dir=""
sql_output_dir=""
tmp_dir=""
vm_user_name=""
grep_cmd=""
sed_cmd=""
md5_cmd=""
md5_col=1
zip_cmd=""
gzip_cmd=""
output_file=""

function check_dependencies() {
  local dependencies=(
    "mysql"
    "grep"
    "sed"
    "cut"
    "tr"
    "date"
    "iconv"
    "wc"
    "tar"
    "gzip"
#    "getent"
  )

  local cmd_not_found=0
  for cmd in "${dependencies[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
      echo "ERROR: Required command '${cmd}' not found in PATH."
      cmd_not_found=1
    fi
  done

  # Special check for md5sum equivalents used in the script
  if ! command -v "md5sum" &> /dev/null && ! command -v "md5" &> /dev/null && ! command -v "csum" &> /dev/null; then
    echo "ERROR: Required command for checksums ('md5sum', 'md5', or 'csum') not found."
    cmd_not_found=1
  fi

  if [[ ${cmd_not_found} -eq 1 ]]; then
    exit 1
  fi
}

# Define global variables that define how/what executables to use based on the platform on which we are running.
function init_variables() {
  LOCALE=$(echo $LANG | cut -d '.' -f 1)
  export LANG=C
  export LANG=${LOCALE}.UTF-8

  script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  sql_cmd=mysql
  output_dir=${script_dir}/output; export output_dir
  sql_output_dir=${output_dir}; export sql_output_dir
  tmp_dir=${script_dir}/tmp
  log_dir=${script_dir}/log
  sql_dir=${script_dir}/sql
  database_type="mysql"

  grep_cmd=$(which grep)
  sed_cmd=$(which sed)
  md5_cmd=$(which md5sum)
  md5_col=1

  if [[ "$(uname)" = "SunOS" ]]; then
    grep_cmd=/usr/xpg4/bin/grep
    sed_cmd=/usr/xpg4/bin/sed
  fi

  if [[ "$(uname)" = "HP-UX" ]]; then
    if [[ -f /usr/local/bin/md5 ]]; then
      md5_cmd=/usr/local/bin/md5
      md5_col=4
    fi
  fi

  zip_cmd=$(which zip 2>/dev/null)
  if [[ "${zip_cmd}" = "" ]]; then
    gzip_cmd=$(which gzip 2>/dev/null)
  fi

  if [[ ! -d ${log_dir} ]]; then
    mkdir -p ${log_dir}
  fi
  if [[ ! -d ${output_dir} ]]; then
    mkdir -p ${output_dir}
  fi

  # Check if running on Windows Subsystem for Linux
  is_windows=$(uname -a | grep -i microsoft |wc -l)
  if [[ ${is_windows} -eq 1 ]]; then
    sql_dir=$(wslpath -a -w "${script_dir}")/sql
    sql_output_dir=$(wslpath -a -w "${sql_output_dir}")
  fi

  # Check if running on Cygwin
  is_cygwin=$(uname -a | grep Cygwin | wc -l)
  if [[ ${is_cygwin} -eq 1 ]]; then
    sql_dir=$(cygpath -w "${script_dir}")/sql
    sql_output_dir=$(cygpath -w "${sql_output_dir}")
    sql_cmd=${sql_cmd}.exe
  fi
}

function check_version() {
  local connect_string="$1"
  local dma_version=$2
  local user; user=$(echo "${connect_string}" | cut -d '/' -f 1)
  local pass; pass=$(echo "${connect_string}" | cut -d '/' -f 2 | cut -d '@' -f 1)
  local host; host=$(echo "${connect_string}" | cut -d '/' -f 4 | cut -d ':' -f 1)
  local port; port=$(echo "${connect_string}" | cut -d ':' -f 2 | cut -d '/' -f 1)
  local db; db=$(echo "${connect_string}"   | cut -d '/' -f 5)

  local db_version; db_version=$(${sql_cmd} --user="${user}" --password="${pass}" -h "${host}" -P "${port}" -s "${db}" << EOF
SELECT version();
EOF
)
  local retcd=$?
  if [[ $retcd -ne 0 ]]; then
	  echo "Error connecting to the target database ${connect_string}."
	  echo "Connection attempt returned: ${db_version}"
	  return ${retcd}
  fi
  echo 'DMAFILETAG~'${db_version}'|'${db_version}'_'${dma_version}'_'${host}'-'${port}'_'${db}'_'${db}'_'$(date +%y%m%d%H%M%S)
}

function execute_dma() {
  local connect_string="${1}"
  local v_file_tag="${2}"
  local v_manual_id="${3}"
  local user; user=$(echo "${connect_string}" | cut -d '/' -f 1)
  local pass; pass=$(echo "${connect_string}" | cut -d '/' -f 2 | cut -d '@' -f 1)
  local host; host=$(echo "${connect_string}" | cut -d '/' -f 4 | cut -d ':' -f 1)
  local port; port=$(echo "${connect_string}" | cut -d ':' -f 2 | cut -d '/' -f 1)
  local db; db=$(echo "${connect_string}"  | cut -d '/' -f 5)

  export DMA_SOURCE_ID; DMA_SOURCE_ID=$(${sql_cmd} --user="${user}" --password="${pass}" -h "${host}" -P "${port}" --force --silent --skip-column-names "${db}" 2>>"${output_dir}/opdb__stderr_${v_file_tag}.log" < "${sql_dir}/init.sql" | tr -d '\r')
  export SCRIPT_PATH; SCRIPT_PATH=$(${sql_cmd} --user="${user}" --password="${pass}" -h "${host}" -P "${port}" --force --silent --skip-column-names "${db}" 2>>"${output_dir}/opdb__stderr_${v_file_tag}.log" < "${sql_dir}/_base_path_lookup.sql" | tr -d '\r')

  for f in $(ls -1 sql/*.sql | "${grep_cmd}" -v -e "init.sql" -e "_base_path_lookup.sql"); do
    echo "Processing SQL FILE ${f}"
    fname=$(echo "${f}" | cut -d '/' -f 2 | cut -d '.' -f 1)
    echo "Fname = ${fname}"
    ${sql_cmd} --user="${user}" --password="${pass}" -h "${host}" -P "${port}" --force --table "${db}" >"${output_dir}/opdb__mysql_${fname}__${v_file_tag}.csv" 2>>"${output_dir}/opdb__stderr_${v_file_tag}.log"  <<EOF
SET @DMA_SOURCE_ID='${DMA_SOURCE_ID}';
SET @DMA_MANUAL_ID='${v_manual_id}';
SET @PKEY='${v_file_tag}';
source ${f}
exit
EOF
    if [[ ! -s "${output_dir}/opdb__mysql_${fname}__${v_file_tag}.csv" ]]; then
      local hdr; hdr=$(echo "${f}" | cut -d '.' -f 1 | rev | cut -d '/' -f 1 | rev)
      cat "${sql_dir}/headers/${hdr}.header" > "${output_dir}/opdb__mysql_${fname}__${v_file_tag}.csv"
    fi
  done

  for f in $(ls -1 "sql/${SCRIPT_PATH}"/*.sql | "${grep_cmd}" -v -E "init.sql|_base_path_lookup.sql|hostname.sql"); do
    fname=$(echo "${f}" | cut -d '/' -f 3 | cut -d '.' -f 1)
    ${sql_cmd} --user="${user}" --password="${pass}" -h "${host}" -P "${port}" --force --table  "${db}" >"${output_dir}/opdb__mysql_${fname}__${v_file_tag}.csv" 2>>"${output_dir}/opdb__stderr_${v_file_tag}.log"  <<EOF
SET @DMA_SOURCE_ID='${DMA_SOURCE_ID}';
SET @DMA_MANUAL_ID='${v_manual_id}';
SET @PKEY='${v_file_tag}';
source ${f}
exit
EOF
    if [[ ! -s "${output_dir}/opdb__mysql_${fname}__${v_file_tag}.csv" ]]; then
      local hdr; hdr=$(echo "${f}" | cut -d '.' -f 1 | rev | cut -d '/' -f 1 | rev)
      cat "${sql_dir}/headers/${hdr}.header" > "${output_dir}/opdb__mysql_${fname}__${v_file_tag}.csv"
    fi
  done

  local serverHostname; serverHostname=$(${sql_cmd} --user="${user}" --password="${pass}" -h "${host}" -P "${port}" --force --silent --skip-column-names "${db}" 2>>"${output_dir}/opdb__stderr_${v_file_tag}.log" < "${sql_dir}/hostname.sql" | tr -d '\r')
   echo "Need server IPs for ${serverHostname}"
  local serverIPs; serverIPs=$(getent hosts "${serverHostname}" | awk '{print $1}' | tr '\n' ',')
  local hostOut; hostOut="${output_dir}/opdb__mysql_db_host_${v_file_tag}.csv"
  echo "HOSTNAME|IP_ADDRESSES" > "${hostOut}"
  echo "\"${serverHostname}\"|\"${serverIPs}\"" >> "${hostOut}"

  local specsOut; specsOut="${output_dir}/opdb__mysql_db_machine_specs_${v_file_tag}.csv"
  ./db-machine-specs.sh "${host}" "${vm_user_name}" "${v_file_tag}" "${DMA_SOURCE_ID}" "${v_manual_id}" "${specsOut}" "${extra_ssh_args[@]}"
}

function create_error_log() {
  local v_file_tag=$1
  echo "Checking for errors..."
  "${grep_cmd}" -E 'ERROR' "${output_dir}/opdb__stderr_${v_file_tag}.log" > "${log_dir}/opdb__${v_file_tag}_errors.log"
  local retval=$?
  if [[ ! -f  "${log_dir}/opdb__${v_file_tag}_errors.log" ]]; then
    echo "Error creating error log. Exiting..."
    return ${retval}
  fi
}

function cleanup_dma_output() {
  local v_file_tag=$1
  echo "Preparing files for compression."
  for outfile in  ${output_dir}/opdb*${v_file_tag}.csv
  do
  if [[ -f $outfile ]] ; then
    if [[ $(uname) = "SunOS" ]]
    then
      ${sed_cmd}  's/ *\|/\|/g;s/\| */\|/g;/^$/d;/^\+/d;s/^|//g;s/|\r//g'  ${outfile} > sed_${v_file_tag}.tmp
      cp sed_${v_file_tag}.tmp ${outfile}
      rm sed_${v_file_tag}.tmp
    else
      if [[ $(uname) = "AIX" ]] ; then
        ${sed_cmd} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${v_file_tag}.tmp
        cp sed_${v_file_tag}.tmp ${outfile}
        rm sed_${v_file_tag}.tmp
      else
        if [[ "$(uname)" = "HP-UX" ]] ; then
          ${sed_cmd} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${v_file_tag}.tmp
          cp sed_${v_file_tag}.tmp ${outfile}
          rm sed_${v_file_tag}.tmp
        else
          if [[ "$(uname)" = "Darwin" ]] ; then
            ${sed_cmd} -r 's/[[:space:]]+\|/\|/g;s/\|[[:space:]]+/\|/g;/^$/d;/^\+/d;s/^\|//g;s/\|$//g;/^(.* row(s)?)/d;1 y/abcdefghijklmnopqrstuvwxyz/ABCDEFGHIJKLMNOPQRSTUVWXYZ/' ${outfile} > sed_${v_file_tag}.tmp
            cp sed_${v_file_tag}.tmp ${outfile}
            rm sed_${v_file_tag}.tmp
          else
            ${sed_cmd} -r 's/[[:space:]]+\|/\|/g;s/\|[[:space:]]+/\|/g;/^$/d;/^\+/d;s/^\|//g;s/\|$//g;/^(.* row(s)?)/d;1 s/[a-z]/\U&/g' ${outfile} > sed_${v_file_tag}.tmp
            cp sed_${v_file_tag}.tmp ${outfile}
            rm sed_${v_file_tag}.tmp
          fi
        fi
      fi
    fi
  fi
  done
}

function compress_dma_files() {
  local v_file_tag=$1
  local v_err_tag=""
  local retval=0
  echo ""
  echo "Archiving output files with tag ${v_file_tag}"
  local current_working_dir; current_working_dir=$(pwd)
  cp "${log_dir}/opdb__${v_file_tag}_errors.log" "${output_dir}/opdb__${v_file_tag}_errors.log"
  if [[ -f VERSION.txt ]]; then
    cp VERSION.txt "${output_dir}/opdb__${v_file_tag}_version.txt"
  else
    echo "No Version file found" >  "${output_dir}/opdb__${v_file_tag}_version.txt"
  fi
  local error_count; error_count=$(wc -l < "${output_dir}/opdb__${v_file_tag}_errors.log")
  if [[ ${error_count} -ne 0 ]]; then
    v_err_tag="_ERROR"
    retval=1
    echo "Errors reported during collection:"
    cat "${output_dir}/opdb__${v_file_tag}_errors.log"
    echo " "
    echo "Please rerun the extract after correcting the error condition."
  fi

  local tarfile_name; tarfile_name="opdb_${database_type}_mysql__${v_file_tag}${v_err_tag}.tar"
  local zipfile_name; zipfile_name="opdb_${database_type}_mysql__${v_file_tag}${v_err_tag}.zip"

  locale > "${output_dir}/opdb__${v_file_tag}_locale.txt"

  echo "dbmajor = ${dbmajor}"  >> "${output_dir}/opdb__defines__${v_file_tag}.csv"
  echo "MANUAL_ID : ${manual_unique_id}" >> "${output_dir}/opdb__defines__${v_file_tag}.csv"
  echo "zipfile_name: ${zipfile_name}" >> "${output_dir}/opdb__defines__${v_file_tag}.csv"

  cd "${output_dir}"
  if [[ -f "opdb__manifest__${v_file_tag}.txt" ]]; then
    rm "opdb__manifest__${v_file_tag}.txt"
  fi

  for file in $(ls -1 opdb*"${v_file_tag}".csv opdb*"${v_file_tag}"*.log opdb*"${v_file_tag}"*.txt)
  do
    local md5_val; md5_val=$(${md5_cmd} "${file}" | cut -d ' ' -f "${md5_col}")
    echo "${database_type}|${md5_val}|${file}"  >> "opdb__manifest__${v_file_tag}.txt"
  done

  if [[ ! "${zip_cmd}" = "" ]]; then
    "${zip_cmd}" "${zipfile_name}" opdb*"${v_file_tag}".csv opdb*"${v_file_tag}"*.log opdb*"${v_file_tag}"*.txt
    output_file=${zipfile_name}
  else
    tar cvf "${tarfile_name}" opdb*"${v_file_tag}".csv opdb*"${v_file_tag}"*.log opdb*"${v_file_tag}"*.txt
    "${gzip_cmd}" "${tarfile_name}"
    output_file="${tarfile_name}.gz"
  fi

  if [[ -f "${output_file}" ]]; then
    rm opdb*"${v_file_tag}".csv opdb*"${v_file_tag}"*.log opdb*"${v_file_tag}"*.txt
  fi

  cd "${current_working_dir}"
  echo ""
  echo "Step completed."
  echo ""
  return ${retval}
}

function get_version() {
  local githash
  if [[ -f VERSION.txt ]]; then
   githash=$(cat VERSION.txt | cut -d '(' -f 2 | tr -d ')' )
  else githash="NONE"
  fi
  echo "${githash}"
}

function print_extractor_version() {
  if [[ "$1" == "NONE" ]]; then
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
    echo "Using release version $1"
  fi
}

function print_usage() {
  echo " Usage:"
  echo "  Parameters"
  echo ""
  echo "  Connection definition must one of:"
  echo "      {"
  echo "        --connectionStr       Connection string formatted as {user}/{password}@//{db host}:{listener port}/{service name}"
  echo "       or"
  echo "        --hostName            Database server host name"
  echo "        --port                Database listener port"
  echo "        --databaseService     Database service name. Required."
  echo "        --collectionUserName  Database user name."
  echo "        --collectionUserPass  Database password"
  echo "      }"
  echo
  echo "  Additional Parameters:"
  echo "        --manualUniqueId      (Optional) A short string to be attached to this collection. Use only when directed."
  echo
  echo "  VM collection definition (optional):"
  echo "        --vmUserName          Username on the VM the Database is running on."
  echo "                              Must be supplied to collect hardware configuration of the database server if"
  echo "                              the collection script is not run directly on the database server."
  echo "        --extraSSHArg         Extra args to be passed as is to ssh. Can be specified multiple times."
  echo
  echo " Example:"
  echo
  echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name}"
  echo " or"
  echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}"
}

function parse_parameters() {
  if [[ $(($# & 1)) == 1 ]] ; then
    echo "Invalid number of parameters. Each parameter must specify a value."
    print_usage
    exit 1
  fi

  while (( "$#" )); do
    if   [[ "$1" == "--hostName" ]];           then host_name="${2}"
    elif [[ "$1" == "--port" ]];               then port="${2}"
    elif [[ "$1" == "--databaseService" ]];    then database_service="${2}"
    elif [[ "$1" == "--collectionUserName" ]]; then collection_user_name="${2}"
    elif [[ "$1" == "--collectionUserPass" ]]; then collection_user_pass="${2}"
    elif [[ "$1" == "--connectionStr" ]];      then conn_str="${2}"
    elif [[ "$1" == "--manualUniqueId" ]];     then manual_unique_id="${2}"
    elif [[ "$1" == "--vmUserName" ]];         then vm_user_name="${2}"
    elif [[ "$1" == "--extraSSHArg" ]];        then extra_ssh_args+=("${2}")
    else
      echo "Unknown parameter ${1}"
      print_usage
      exit 1
    fi
    shift 2
  done

  if [[ "${conn_str}" == "" ]] ; then
    if [[ "${host_name}" != "" && "${port}" != "" && "${database_service}" != "" && "${collection_user_name}" != "" && "${collection_user_pass}" != "" ]] ; then
      conn_str="${collection_user_name}/${collection_user_pass}@//${host_name}:${port}/${database_service}"
    else
      echo "Connection information incomplete"
      print_usage
      exit 1
    fi
  fi

  if [[ "${manual_unique_id}" != "" ]] ; then
    case "$(uname)" in
      "Solaris" )
            manual_unique_id=$(echo "${manual_unique_id}" | iconv -t ascii//TRANSLIT | "${sed_cmd}" -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      "Darwin" | "Linux" )
            manual_unique_id=$(echo "${manual_unique_id}" | iconv -t ascii//TRANSLIT | "${sed_cmd}" -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      "HP-UX" )
            manual_unique_id=$(echo "${manual_unique_id}" | tr -c '[:alnum:]\n' '-' |  sed 's/^-//; s/-$//' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      "AIX" )
            manual_unique_id=$(echo "${manual_unique_id}" | iconv -f "$(locale charmap)" -t UTF-8 | tr -c '[:alnum:]\n' '-' |  sed 's/^-//; s/-$//' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
    esac
  else
    manual_unique_id='NA'
  fi
}

function check_db_connection() {
  local sqlcmd_result=$(check_version "${connect_string}" "${dma_version}")
  local retval=$?
  if [[ ${retval} -ne 0 ]]; then
    echo " "
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Unable to connect to the target MySQL database. Please verify the connection information and target database status."
    echo "Got: ${sqlcmd_result}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  fi
  echo "${sqlcmd_result}" | "${grep_cmd}" DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r'
}

function main() {
  check_dependencies
  init_variables
  parse_parameters "$@"
  connect_string="${conn_str}"

  local extractor_version="$(get_version)"
  echo ""
  echo "==================================================================================="
  echo "Database Migration Assessment Database Assessment Collector Version ${dma_version}"
  print_extractor_version "${extractor_version}"
  echo "==================================================================================="

  local sqlcmd_result; sqlcmd_result=$(check_db_connection)
  local retval=$?

  if [[ ${retval} -eq 0 ]]; then
    if [[ "$(echo "${sqlcmd_result}" | "${grep_cmd}" -E '(ERROR|FATAL)')" != "" ]]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database version check returned error ${sqlcmd_result}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Exiting...."
      exit 255
    else
      echo "Your database version is $(echo "${sqlcmd_result}" | cut -d '|' -f1)"
      dbmajor=$(echo "${sqlcmd_result}" | cut -d '|' -f 1 | cut -d '.' -f 1)
      V_TAG="$(echo "${sqlcmd_result}" | cut -d '|' -f2).csv"; export V_TAG

      execute_dma "${connect_string}" "$(echo "${V_TAG}" | "${sed_cmd}" 's/.csv//g')" "${manual_unique_id}"
      retval=$?
      if [[ ${retval} -ne 0 ]]; then
        create_error_log  $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
        compress_dma_files $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Database Migration Assessment extract reported an error.  Please check the error log in directory ${log_dir}"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Exiting...."
        exit 255
      fi

      create_error_log  $(echo ${V_TAG} | sed 's/.csv//g')
      cleanup_dma_output $(echo ${V_TAG} | sed 's/.csv//g')
      retval=$?
      if [[ ${retval} -ne 0 ]]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Database Migration Assessment data sanitation reported an error. Please check the error log in directory ${output_dir}"
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Exiting...."
        exit 255
      fi

      compress_dma_files $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g') ${host_name}
      retval=$?
      if [[ ${retval} -ne 0 ]]; then
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Database Migration Assessment data file archive encountered a problem.  Exiting...."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 255
      fi

      echo ""
      echo "==================================================================================="
      echo "Database Migration Assessment Database Assessment Collector completed."
      echo "Data collection located at ${output_dir}/${output_file}"
      echo "==================================================================================="
      echo ""
      print_extractor_version "${extractor_version}"
      exit 0
    fi
  else
    echo "A failure occurred during database connection."
    exit 255
  fi
}

main "$@"
