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

### Setup directories needed for execution
#############################################################################


# Global variables and constants
dma_version="4.3.45"
all_dbs=""
collection_user_name=""
collection_user_pass=""
conn_str=""
connect_string=""
database_service="postgres"
database_type="postgres"
dbmajor=""
extra_ssh_args=()
host_name=""
log_dir=""
manual_unique_id=""
output_dir=""
port=""
script_dir=""
specs_path=""
sql_cmd=""
sql_dir=""
sql_output_dir=""
stats_source=""
tmp_dir=""
vm_user_name=""
grep_cmd=""
sed_cmd=""
md5_cmd=""
md5_col=1
zip_cmd=""
gzip_cmd=""


function check_dependencies() {
  local dependencies=(
    "psql"
    "grep"
    "sed"
    "cut"
    "tr"
    "date"
    "iconv"
    "wc"
    "tar"
    "gzip"
  )

  local cmd_not_found=0
  for cmd in "${dependencies[@]}"; do
    if ! command -v "${cmd}" &> /dev/null; then
      echo "ERROR: Required command '\${cmd}' not found in PATH." >&2
      cmd_not_found=1
    fi
  done

  # Special check for md5sum equivalents used in the script
  if ! command -v "md5sum" &> /dev/null && ! command -v "md5" &> /dev/null && ! command -v "csum" &> /dev/null; then
    echo "ERROR: Required command for checksums ('md5sum', 'md5', or 'csum') not found." >&2
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
  sql_cmd=psql
  output_dir=${script_dir}/output; export output_dir
  sql_output_dir=${output_dir}; export sql_output_dir
  tmp_dir=${script_dir}/tmp
  log_dir=${script_dir}/log
  sql_dir=${script_dir}/sql
  database_type="postgres"

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
    sql_dir=$(wslpath -a -w ${script_dir})/sql
    sql_output_dir=$(wslpath -a -w ${sql_output_dir})
  fi

  # Check if running on Cygwin
  is_cygwin=$(uname -a | grep Cygwin | wc -l)
  if [[ ${is_cygwin} -eq 1 ]]; then
    sql_dir=$(cygpath -w ${script_dir})/sql
    sql_output_dir=$(cygpath -w ${sql_output_dir})
    sql_cmd=${sql_cmd}.exe
  fi
}

function check_version() {
  local connect_string="$1"
  local dma_version=$2
  local retcd=""
  local user=$(echo "${connect_string}" | cut -d '/' -f 1)
  local pass=$(echo "${connect_string}" | cut -d '/' -f 2 | cut -d '@' -f 1)
  local host=$(echo "${connect_string}" | cut -d '/' -f 4 | cut -d ':' -f 1)
  local port=$(echo "${connect_string}" | cut -d ':' -f 2 | cut -d '/' -f 1)
  local db=$(echo "${connect_string}"   | cut -d '/' -f 5)

  export PGPASSWORD="${pass}"
  if ! [[ -x "$(command -v ${sql_cmd})" ]]; then
    echo "Could not find ${sql_cmd} command. Source in environment and try again"
    echo "Exiting..."
    exit 1
  fi

  local db_version=$(PGPASSWORD="${pass}" ${sql_cmd} -X --user=${user} -h ${host} -w -p ${port} -d "${db}" -t --no-align  2>&1 << EOF
SELECT current_setting('server_version_num');
EOF
)
  local retcd=$?
  if [[ $retcd -ne 0 ]] ; then
	  echo "Error connecting to the target database ${connect_string} ."
	  echo "Connection attempt returned : ${db_version}"
	  return $retcd
  fi

  echo 'DMAFILETAG~'${db_version}'|'${db_version}'_'${dma_version}'_'${host}'-'${port}'_'${db}'_'${db}'_'$(date +%y%m%d%H%M%S)
}


function execute_dma() {
  local connect_string="${1}"
  local dma_version="${2}"
  local v_file_tag="${3}"
  local v_manual_id="${4}"
  local v_pgversion="${5}"
  local all_dbs="${6}"
  local user=$(echo "${connect_string}" | cut -d '/' -f 1)
  local pass=$(echo "${connect_string}" | cut -d '/' -f 2 | cut -d '@' -f 1)
  local host=$(echo "${connect_string}" | cut -d '/' -f 4 | cut -d ':' -f 1)
  local port=$(echo "${connect_string}" | cut -d ':' -f 2 | cut -d '/' -f 1)
  local db=$(echo "${connect_string}"  | cut -d '/' -f 5)

  if ! [[ -x "$(command -v ${sql_cmd})" ]]; then
    echo "Could not find ${sql_cmd} command. Source in environment and try again"
    echo "Exiting..."
    exit 1
  fi


  local dma_source_id=$(PGPASSWORD="${pass}" ${sql_cmd} -X --user=${user}  -h ${host} -w -p ${port} -d "${db}" -t --no-align <<EOF
  SELECT system_identifier FROM pg_control_system();
EOF
  )


  if [[ "${v_manual_id}" == "" ]]
  then
    v_manual_id="NA"
  fi

  if [[ "${dma_source_id}" == "" ]]
  then
    dma_source_id="NA"
  fi

  # Only run once per VM, instead of once per DB.
  local vm_specs_output_file="output/opdb__pg_db_machine_specs_${host}.csv"
  if [[ ! -f "${vm_specs_output_file}" ]] ; then
        host=$(echo "${connect_string}" | cut -d '/' -f 4 | cut -d ':' -f 1)
        ./db-machine-specs.sh "$host" "$vmUserName" "${v_file_tag}" "${dma_source_id}" "${v_manual_id}" "${vm_specs_output_file}" "${extra_ssh_args[@]}"
  fi

  # If all_dbs = "Y" loop through all the databases in the instance and create a collection for each one, then exit.
  if [[ "${all_dbs}" == "Y" ]] ; then
    export OLDIFS=$IFS
    IFS=$(echo -en "\n\b")
    echo PGPASSWORD="${pass}" ${sql_cmd}  --user=${user}  -h ${host} -w -p ${port} -d "${db}" -t --no-align
    dblist=$(PGPASSWORD="${pass}" ${sql_cmd}  --user=${user}  -h ${host} -w -p ${port} -d "${db}" -t --no-align <<EOF
SELECT datname FROM pg_database WHERE datname NOT LIKE 'template%' ORDER BY datname;
EOF
    )

    for db in ${dblist}
    do
      export dma_recursion=1
      export IFS=$OLDIFS
      ./collect-data.sh --connectionStr ${user}/${pass}@//${host}:${port}/"${db}"  --manualUniqueId ${v_manual_id}  --specsPath "$vm_specs_output_file" --allDbs N
    done
    if [[ -f ${vm_specs_output_file} ]]; then
      rm ${vm_specs_output_file}
    fi
    exit
  else
  # If given a database name, create a collection for that one database.
  export PGPASSWORD="$pass"
  ${sql_cmd} -X --user=${user} -d "${db}" -h ${host} -w -p ${port}  --no-align --echo-errors 2>output/opdb__stderr_${v_file_tag}.log <<EOF
  \set VTAG ${v_file_tag}
  \set PKEY '\'${v_file_tag}\''
  \set DMA_SOURCE_ID '\'${dma_source_id}\''
  \set DMA_MANUAL_ID '\'${v_manual_id}\''
  \set VPGVERSION ${v_pgversion}
  \i sql/op_collect.sql
EOF

  fi
}


# Check the output files for error messages
function create_error_log() {
  local v_file_tag=$1
  echo "Checking for errors..."
  if [[ "$database_type" == "postgres" ]]; then
    $grep_cmd  -i -E 'ERROR:' ${output_dir}/opdb__stderr_${v_file_tag}.log > ${log_dir}/opdb__${v_file_tag}_errors.log
    local retval=$?
  fi
  if [[ ! -f  ${log_dir}/opdb__${v_file_tag}_errors.log ]]; then
    echo "Error creating error log.  Exiting..."
    return $retval
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
  local v_hostname=$2
  local v_err_tag=""

  echo ""
  echo "Archiving output files with tag ${v_file_tag}"
  locsl current_working_dir=$(pwd)
  cp ${log_dir}/opdb__${v_file_tag}_errors.log ${output_dir}/opdb__${v_file_tag}_errors.log
  if [[ -f VERSION.txt ]]; then
    cp VERSION.txt ${output_dir}/opdb__${v_file_tag}_version.txt
  else
    echo "No Version file found" >  ${output_dir}/opdb__${v_file_tag}_version.txt
  fi
  # Copy machine specs file to final file name.
  if [[ -f ${output_dir}/opdb__pg_db_machine_specs_${v_hostname}.csv ]]; then
    cp ${output_dir}/opdb__pg_db_machine_specs_${v_hostname}.csv ${output_dir}/opdb__pg_db_machine_specs_${v_file_tag}.csv
  fi
  # If not a recursive call, remove the db_machine_specs file
  if [[ ${dma_recursion} -ne 1 ]] && [[ -f ${output_dir}/opdb__pg_db_machine_specs_${v_hostname}.csv ]]; then
    rm  ${output_dir}/opdb__pg_db_machine_specs_${v_hostname}.csv
  fi
  local error_count=$(wc -l < ${output_dir}/opdb__${v_file_tag}_errors.log)
  if [[ ${error_count} -ne 0 ]]
  then
    v_err_tag="_ERROR"
    retval=1
    echo "Errors reported during collection:"
    cat ${output_dir}/opdb__${v_file_tag}_errors.log
    echo " "
    echo "Please rerun the extract after correcting the error condition."
  fi

  local tarfile_name=opdb_${database_type}_${database_type}__${v_file_tag}${v_err_tag}.tar
  local zipfile_name=opdb_${database_type}_${database_type}__${v_file_tag}${v_err_tag}.zip

  locale > ${output_dir}/opdb__${v_file_tag}_locale.txt

  echo "dbmajor = ${dbmajor}"  >> ${output_dir}/opdb__defines__${v_file_tag}.csv
  echo "MANUAL_ID : " ${manual_unique_id} >> ${output_dir}/opdb__defines__${v_file_tag}.csv
  echo "zipfile_name: " $zipfile_name >> ${output_dir}/opdb__defines__${v_file_tag}.csv

  cd ${output_dir}
  if [[ -f opdb__manifest__${v_file_tag}.txt ]]; then
    rm opdb__manifest__${v_file_tag}.txt
  fi

  for file in $(ls -1  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt)
  do
    md5_val=$(${md5_cmd} $file | cut -d ' ' -f ${md5_col})
    echo "${database_type}|${md5_val}|${file}"  >> opdb__manifest__${v_file_tag}.txt
  done

  if [[ ! "${zip_cmd}" = "" ]]; then
    ${zip_cmd} ${zipfile_name}  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt
    output_file=${zipfile_name}
  else
    tar cvf ${tarfile_name}  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt
    ${gzip_cmd} ${tarfile_name}
    output_file=${tarfile_name}.gz
  fi

  if [[ -f ${output_file} ]]; then
    rm opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt
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
  if [[ "$1" == "NONE" ]];
  then
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
  echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} --all_dbs N"
  echo " or"
  echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --allDbs N"
  echo
  echo " To collect data for all databases in the instance:"
  echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} "
  echo " or"
  echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}"
}

function parse_parameters() {
  if [[ $(($# & 1)) == 1 ]] ;
  then
    echo "Invalid number of parameters $# $@"
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
    elif [[ "$1" == "--specsPath" ]];          then specs_path=("${2}")
    elif [[ "$1" == "--allDbs" ]];             then all_dbs=("${2}")
    else
      echo "Unknown parameter ${1}"
      print_usage
      exit 1
    fi
    shift 2
  done

  if [[ "${conn_str}" == "" ]] ; then
    if [[ "${host_name}" != "" && "${port}" != "" && "${collection_user_name}" != "" && "${collection_user_pass}" != "" ]] ; then
      baseConnStr="${collection_user_name}/${collection_user_pass}@//${host_name}:${port}"
      if [[ "${database_service}" != "" ]]; then
            conn_str="${baseConnStr}/${database_service}"
      else conn_str="${baseConnStr}"
      fi
    else
      echo "Connection information incomplete"
      print_usage
      exit 1
    fi
  else
      host_name=$(echo ${conn_str} | cut -d '/' -f 4 | cut -d ':' -f 1)
  fi


  if [[ "${all_dbs}" != "Y" && "${all_dbs}" != "N" ]] ; then
    echo "Invalid value supplied for parameter all_dbs.  Must be Y or N."
    print_usage
    exit 255
  fi

  if [[ "${manual_unique_id}" != "" ]] ; then
    case "$(uname)" in
      "Solaris" )
            manual_unique_id=$(echo "${manual_unique_id}" | iconv -t ascii//TRANSLIT | ${sed_cmd} -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      ( "Darwin" | "Linux" )
            manual_unique_id=$(echo "${manual_unique_id}" | iconv -t ascii//TRANSLIT | ${sed_cmd} -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      "HP-UX" )
            manual_unique_id=$(echo "${manual_unique_id}" | tr -c '[:alnum:]\n' '-' |  sed 's/^-//; s/-$//' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      "AIX" )
            manual_unique_id=$(echo "${manual_unique_id}" | iconv -f $(locale charmap) -t UTF-8 | tr -c '[:alnum:]\n' '-' |  sed 's/^-//; s/-$//' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
            ;;
      esac
  else
    manual_unique_id='NA'
  fi
}


function check_db_connection() {
  echo "Checking connection ${connect_string}"
  local sqlcmd_result=$(check_version "${connect_string}" "${dma_version}" )
  local retval=$?
  if [[ $retval -ne 0 ]]; then
    echo " "
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Unable to connect to the target Postgres database.  Please verify the connection information and target database status."
    echo "Got ${sqlcmd_result}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    exit 255
  fi
  echo "${sqlcmd_result}" | "${grep_cmd}" DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r'
}


# MAIN
#############################################################################

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

  if [[ $retval -eq 0 ]]; then
    if [[ "$(echo ${sqlcmd_result} | $grep_cmd -E '(ORA-|SP2-|ERROR|FATAL)')" != "" ]]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database version check returned error ${sqlcmd_result}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Exiting...."
      exit 255
    else
      echo "Your database version is $(echo "${sqlcmd_result}" | cut -d '|' -f1)"
      dbmajor=$((echo "${sqlcmd_result}" | cut -d '|' -f1)  |cut -d '.' -f 1)
      V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).csv"; export V_TAG

      PGVER=$(echo $dbmajor | cut -c 1-2)
      if [[ $PGVER -gt 13 ]] && [[ $PGVER -lt 17 ]] ; then
        PGVER="base"
      fi

      execute_dma "${connect_string}" ${dma_version} $(echo "${V_TAG}" | "${sed_cmd}" 's/.csv//g') "${manual_unique_id}" "${PGVER}" "${all_dbs}"
      retval=$?
      if [[ ${retval} -ne 0 ]]; then
        create_error_log  $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
        compress_dma_files $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g') ${host_name}
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
    echo "Error executing SQL*Plus"
    exit 255
  fi
}

main "$@"
