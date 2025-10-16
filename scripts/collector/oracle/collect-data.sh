#!/bin/bash
set -e
# Copyright 2024 Google LLC
#
# Licensed under the Apache License, Version 2.0 (the "License").
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

. ./dma_print_pass_fail.sh
. ./dma_oee.sh

### Setup directories needed for execution
#############################################################################
dma_version="4.3.44"
dbmajor=""
dbdomain=""

# Force LANG and LOCALE to C UTF8
export LOCALE=C
export LANG=$(locale -a | grep -i -e "^c.utf8" -e "^c.utf-8" | sort | head -1)


script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
sql_plus=sqlplus
output_dir=${script_dir}/output; export output_dir
sql_output_dir=${output_dir}; export sql_output_dir
oracle_path=${script_dir}; export oracle_path
tmp_dir=${script_dir}/tmp
log_dir=${script_dir}/log
sql_dir=${script_dir}/sql
oee_dir=${script_dir}/oee

grep_cmd=$(which grep)
sed_cmd=$(which sed)
md5_cmd=$(which md5sum 2>/dev/null)
md5_col=1

if [ "$(uname)" = "SunOS" ]; then
  grep_cmd=/usr/xpg4/bin/grep
  sed_cmd=/usr/xpg4/bin/sed
fi

if [ "$(uname)" = "HP-UX" ]; then
  if [ -f /usr/local/bin/md5 ]; then
    md5_cmd=/usr/local/bin/md5
    md5_col=4
  else if [ -f /usr/bin/csum ]; then
      md5_cmd="/usr/bin/csum -h md5_val"
      md5_col=1
    fi
  fi
fi

zip_cmd=$(which zip 2>/dev/null)
if [ "${zip_cmd}" = "" ]; then
  gzip_cmd=$(which gzip 2>/dev/null)
fi

if [ ! -d ${log_dir} ]; then
  mkdir -p ${log_dir}
fi
if [ ! -d ${output_dir} ]; then
  mkdir -p ${output_dir}
fi

# Check if running on Windows Subsystem for Linux
is_windows=$(uname -a | grep -i microsoft |wc -l)
if [ ${is_windows} -eq 1 ]; then
  sql_dir=$(wslpath -a -w ${script_dir})/sql
  sql_output_dir=$(wslpath -a -w ${sql_output_dir})
  sql_plus=sqlplus.exe
fi

# Check if running on Cygwin
is_cygwin=$(uname -a | grep Cygwin | wc -l)
if [ ${is_cygwin} -eq 1 ]; then
  sql_dir=$(cygpath -w ${script_dir})/sql
  sql_output_dir=$(cygpath -w ${sql_output_dir})
  sql_plus=sqlplus.exe
fi

### Import logging & helper functions
#############################################################################

function check_version() {
  local connect_string="$1"
  local dma_version=$2

  if ! [[ -x "$(command -v ${sql_plus})" ]]; then
    echo "Could not find ${sql_plus} command. Source in environment and try again"
    echo "Exiting..."
    exit 1
  fi

  ${sql_plus} -s /nolog << EOF
SET DEFINE OFF
connect ${connect_string}
@${sql_dir}/dma_set_sql_env.sql
set pagesize 0 lines 400 feedback off verify off heading off echo off timing off time off
column vname new_value v_name noprint
select min(object_name) as vname from dba_objects where object_name in ('V\$INSTANCE', 'GV\$INSTANCE');
select 'DMAFILETAG~'|| i.version||'|'||substr(replace(i.version,'.',''),0,3)||'_'||'${dma_version}_'||i.host_name||'_'||d.name||'_'||i.instance_name||'_'||to_char(sysdate,'MMDDRRHH24MISS')||'~'
from ( SELECT case when version like '9%' then '0' || version else version end as version, host_name, instance_name FROM &&v_name WHERE instance_number = (SELECT min(instance_number) FROM &&v_name) ) i, v\$database d;
exit;
EOF
}

function execute_dma() {
  local connect_string="$1"
  local dma_version=$2
  local DiagPack=$(echo $3 | tr [[:upper:]] [[:lower:]])
  local manualUniqueId="${4}"
  local statsWindow=${5}

  if ! [ -x "$(command -v ${sql_plus})" ]; then
    echo "Could not find ${sql_plus} command. Source in environment and try again"
    echo "Exiting..."
    exit 1
  fi


  ${sql_plus} -s /nolog << EOF
SET DEFINE OFF
connect ${connect_string}
@${sql_dir}/dma_collect.sql ${dma_version} ${sql_dir} ${DiagPack} ${V_TAG} ${sql_output_dir} "${manualUniqueId}" ${statsWindow}
exit;
EOF

}

function create_error_log() {
  local v_file_tag=$1
  echo "Checking for errors..."
  $grep_cmd -E 'SP2-|ORA-' ${output_dir}/opdb__*${v_file_tag}.csv | $grep_cmd -v opatch > ${log_dir}/opdb__${v_file_tag}_errors.log
  retval=$?
  if [ ! -f  ${log_dir}/opdb__${v_file_tag}_errors.log ]; then
    echo "Error creating error log.  Exiting..."
    return $retval
  fi
  if [ -f  ${output_dir}/opdb__opatch*${v_file_tag}.csv ]; then
    $grep_cmd 'sys.dbms_qopatch.get_opatch_lsinventory' ${output_dir}/opdb__opatch*${v_file_tag}.csv >> ${log_dir}/opdb__${v_file_tag}_errors.log
  fi
}


# Strip out extranneous spaces in the output.
function cleanup_dma_output() {
  local v_file_tag=$1
  echo "Preparing files for compression."
  for outfile in  ${output_dir}/opdb*${v_file_tag}.csv
  do
    if [ -f $outfile ] ; then
      if [ $(uname) = "SunOS" ]; then
        ${sed_cmd} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${v_file_tag}.tmp
        cp sed_${v_file_tag}.tmp ${outfile}
        rm sed_${v_file_tag}.tmp
      else
        if [ $(uname) = "AIX" ]; then
          ${sed_cmd} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${v_file_tag}.tmp
          cp sed_${v_file_tag}.tmp ${outfile}
          rm sed_${v_file_tag}.tmp
        else
          if [ "$(uname)" = "HP-UX" ]; then
            ${sed_cmd} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${v_file_tag}.tmp
            cp sed_${v_file_tag}.tmp ${outfile}
            rm sed_${v_file_tag}.tmp
          else
            ${sed_cmd} -r 's/[[:space:]]+\|/\|/g;s/\|[[:space:]]+/\|/g;/^$/d' ${outfile} > sed_${v_file_tag}.tmp
            cp sed_${v_file_tag}.tmp ${outfile}
            rm sed_${v_file_tag}.tmp
          fi
        fi
      fi
    fi
  done
}


function compress_dma_files() {
  local v_file_tag=$1
  local db_type=$2
  local v_err_tag=""
  local err_cnt
  local -i retval
  local tar_file
  local zip~file

  echo ""
  echo "Archiving output files with tag ${v_file_tag}"

  current_working_dir=$(pwd)
  cp ${log_dir}/opdb__${v_file_tag}_errors.log ${output_dir}/opdb__${v_file_tag}_errors.log
  if [ -f VERSION.txt ]; then
    cp VERSION.txt ${output_dir}/opdb__${v_file_tag}_version.txt
  else
    echo "No Version file found" >  ${output_dir}/opdb__${v_file_tag}_version.txt
  fi

  err_cnt=$(wc -l < ${output_dir}/opdb__${v_file_tag}_errors.log)
  if [ ! -f ${output_dir}/opdb__eoj__${v_file_tag}.csv ] ; then
    err_cnt=$((${err_cnt} + 1))
    echo "End of job marker file not found.  Data collection did not complete."
  fi
  if [[ ${err_cnt} -ne 0 ]]; then
    v_err_tag="_ERROR"
    retval=1
    echo "Errors reported during collection:"
    cat ${output_dir}/opdb__${v_file_tag}_errors.log
    echo " "
    echo "Please rerun the extract after correcting the error condition."
  fi

  tar_file=opdb_oracle_${DIAGPACKACCESS}__${v_file_tag}${v_err_tag}.tar
  zip_file=opdb_oracle_${DIAGPACKACCESS}__${v_file_tag}${v_err_tag}.zip

  locale > ${output_dir}/opdb__${v_file_tag}_locale.txt

  echo "dbmajor = ${dbmajor}"  >> ${output_dir}/opdb__defines__${v_file_tag}.csv
  echo "ZIP_FILE: " ${zip_file} >> ${output_dir}/opdb__defines__${v_file_tag}.csv

  cd ${output_dir}
  if [ -f opdb__manifest__${v_file_tag}.txt ]; then
    rm opdb__manifest__${v_file_tag}.txt
  fi

  # Skip creating the manifest file if the platform does not have md5_cmd installed
  for file in $(ls -1  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt)
  do
    if [ -f "${md5_cmd}" ] ; then
      md5_val=$(${md5_cmd} $file | cut -d ' ' -f ${md5_col})
    else
      md5_val="N/A"
    fi
    echo "${db_type}|${md5_val}|${file}"  >> opdb__manifest__${v_file_tag}.txt
  done

  if [ ! "${zip_cmd}" = "" ]; then
    ${zip_cmd} ${zip_file}  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt
    OUTFILE=${zip_file}
  else
    tar cvf "${tar_file}"  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt
    $gzip_cmd "${tar_file}"
    OUTFILE="${tar_file}".gz
  fi

  if [ -f $OUTFILE ]; then
    rm  opdb*${v_file_tag}.csv opdb*${v_file_tag}*.log opdb*${v_file_tag}*.txt
  fi

  cd ${current_working_dir}
  echo ""
  echo "Step completed."
  echo ""
  return ${retval}
}

function get_version() {
  local githash
  if [ -f VERSION.txt ]; then
    githash=$(cat VERSION.txt | cut -d '(' -f 2 | tr -d ')' )
  else
    githash="NONE"
  fi
  echo "$githash"
}

function print_extractor_version() {
  if [ "$1" == "NONE" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "This appears to be an unsupported version of this code. "
    echo "Please download the latest stable version from "
    echo "https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-oracle.zip"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  else
    echo "Using release version $1"
  fi

}


function get_dma_source_id() {
  echo $(${grep_cmd} v_dma_source_id ${output_dir}/opdb__defines__${1} | cut -d '=' -f 2 | tr -d ' ')
}



function print_usage() {
  echo " Usage:"
  echo "  Parameters"
  echo ""
  echo "  Connection definition must one of:"
  echo "      {"
  echo "        --connectionStr       Oracle EasyConnect string formatted as {user}/{password}@//{db host}:{listener port}/{service name}"
  echo "       or"
  echo "        --hostName            Database server host name"
  echo "        --port                Database Listener port"
  echo "        --databaseService     Database service name"
  echo "        --collectionUserName  Database user name"
  echo "        --collectionUserPass  Database password"
  echo "      }"
  echo "  Performance statistics source"
  echo "      --statsSrc              Required. Must be one of AWR, STATSPACK, NONE.   When using STATSPACK, see note about --statsWindow parameter below."
  echo ""
  echo "  Performance statistics window"
  echo "      --statsWindow           Optional. Number of days of performance stats to collect.  Must be one of 7, 30.  Default is 30."
  echo "                              NOTE: IF STATSPACK HAS LESS THAN 30 DAYS OF COLLECTION DATA, SET THIS PARAMETER TO 7 TO LIMIT TO 1 WEEK OF COLLECTION."
  echo "                              IF STATSPACK HAS BEEN ACTIVATED SPECIFICALLY FOR DMA COLLECTION, ENSURE THERE ARE AT LEAST 8"
  echo "                              CALENDAR DAYS OF COLLECTION BEFORE RUNNING THE DMA COLLECTOR."

  echo "  Oracle Estate Explorere collection"
  echo "      --collectOEE            Optional.  Y or N flag to run the Oracle Estate Explorer data collection in addition to the DMA collector."
  echo "                              NOTE: This requires SQL client version 21 and above, plus Oracle database 11.2 or above."
  echo "                                    OEE collection will not run if requirements are not met."
  echo
  echo "      --oeeGroup              Required if --collectOEE is Y.  This is the group name (ex: Dev, Prod, QA, etc) to use for bundling multiple databases togegther within OEE."
  echo "                              Maximum length of 32 characters."
  echo "      --oeeRunId              Internal use only.  This is used by DMA automation to handle parallel runs of multiple collections."
  echo
  echo " Optional identifier"
  echo "      --manualUniqueId        Optional.  Allows the end user to create a unique identifier with which to tag the collection. "
  echo "                              Also used internally by DMA automation."
  echo
  echo " Example:"
  echo
  echo
  echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name} --statsSrc AWR"
  echo " or"
  echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name} --statsSrc AWR"

}
### Validate input

hostName=""
port=""
databaseService=""
collectionUserName=""
collectionUserPass=""
dbType=""
statsSrc=""
connStr=""
manualUniqueId=""
statsWindow=30
collectOEE="Y"
oeeGroup="NONE"
oeeRunId=$(date +%Ym%d%H%M%S)

if [[ $(($# & 1)) == 1 ]] ; then
  echo "Invalid number of parameters : $# $@"
  print_usage
  exit
fi

while (( "$#" )); do
  if   [[ "$1" == "--hostName" ]];           then hostName="${2}"
  elif [[ "$1" == "--port" ]];               then port="${2}"
  elif [[ "$1" == "--databaseService" ]];    then databaseService="${2}"
  elif [[ "$1" == "--collectionUserName" ]]; then collectionUserName="${2}"
  elif [[ "$1" == "--collectionUserPass" ]]; then collectionUserPass="${2}"
  elif [[ "$1" == "--dbType" ]];             then dbType=$(echo "${2}" | tr '[:upper:]' '[:lower:]')
  elif [[ "$1" == "--statsSrc" ]];           then statsSrc=$(echo "${2}" | tr '[:upper:]' '[:lower:]')
  elif [[ "$1" == "--connectionStr" ]];      then connStr="${2}"
  elif [[ "$1" == "--manualUniqueId" ]];     then manualUniqueId="${2}"
  elif [[ "$1" == "--statsWindow" ]];        then statsWindow="${2}"
  elif [[ "$1" == "--collectOEE" ]];         then collectOEE="${2}"
  elif [[ "$1" == "--oeeGroup"   ]];         then oeeGroup="${2}"
  elif [[ "$1" == "--oeeRunId"   ]];         then oeeRunId="${2}"
  elif [[ "$1" == "--dmaAutomation"   ]];    then dmaAutomation="${2}"  # Internal use only
  else
    echo "Unknown parameter ${1}"
    print_usage
    exit
  fi
  shift 2
done

if [[ "${dbType}" != "oracle" ]] ; then
  dbType="oracle"
fi

if [[ "${statsSrc}" = "awr" ]]; then
  DIAGPACKACCESS="UseDiagnostics"
elif [[ "${statsSrc}" = "statspack" ]] ; then
  DIAGPACKACCESS="NoDiagnostics"
else
  echo No performance data will be collected.
  DIAGPACKACCESS="nostatspack"
fi

if [[ ${statsWindow} -ne 30 ]] && [[ ${statsWindow} -ne 7 ]] ; then
  statsWindow=30
fi

if [[ "${connStr}" == "" ]] ; then
  if [[ "${hostName}" != "" && "${port}" != "" && "${databaseService}" != "" && "${collectionUserName}" != "" && "${collectionUserPass}" != "" ]] ; then
    connStr="${collectionUserName}/${collectionUserPass}@//${hostName}:${port}/${databaseService}"
    echo Got Connection ${connStr}
  else
    echo "Connection information incomplete"
    print_usage
    exit
  fi
else
  # Parse the EZ connect string to get the user/pass for OEE
  collectionUserName=$(echo ${connStr} | cut -d '/' -f 1)
  collectionUserPass=$(echo ${connStr} | cut -d '/' -f 2 | cut -d '@' -f 1)
  hostPort=$(echo ${connStr} | cut -d '/' -f 4)
  hostName=$(echo ${hostPort} | cut -d ':' -f 1)
  port=$(echo ${hostPort} | cut -d ':' -f 2)
  databaseService=$(echo ${connStr} | cut -d '/' -f 5)
fi

if [[ "${collectOEE}" == "Y" ]] ; then
  if [[ "${oeeGroup}" == "" ]] ; then
    echo "ERROR: Parameter --oeeGroup must be specified if --collectOEE is Y."
    print_usage
    exit
  fi
  if [[ "${oeeRunId}" == "" ]] ; then
    oeeRunId=$$
    oeeRunId="${oeeRunId}_$(date +%Y%m%d%H%M%S)"
  fi
  if [[ ! -f $oee_dir/oee_group_extract-SA.sh ]]; then
    echo "ERROR: Oracle Estate Explorer extraction scripts not found in ${oee_dir}".
    print_usage
    exit
  fi
fi

if [[ "${manualUniqueId}" != "" ]] ; then
  case "$(uname)" in
    "Solaris" )
          manualUniqueId=$(echo "${manualUniqueId}" | iconv -t ascii//TRANSLIT | ${sed_cmd} -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
          ;;
    ( "Darwin" | "Linux" )
          manualUniqueId=$(echo "${manualUniqueId}" | iconv -t ascii//TRANSLIT | ${sed_cmd} -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100) 
          ;; 
    "HP-UX" )
          manualUniqueId=$(echo "${manualUniqueId}" | tr -c '[:alnum:]\n' '-' |  sed 's/^-//; s/-$//' | tr '[:upper:]' '[:lower:]' | cut -c 1-100) 
          ;;
    "AIX" )
          manualUniqueId=$(echo "${manualUniqueId}" | iconv -f $(locale charmap) -t UTF-8 | tr -c '[:alnum:]\n' '-' |  sed 's/^-//; s/-$//' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
          ;;
    esac
else
  manualUniqueId='NA'
fi

#############################################################################
#
# MAIN
#############################################################################

connect_string="${connStr}"
sqlcmd_result=$(check_version "${connect_string}" "${dma_version}" | $grep_cmd DMAFILETAG | cut -d '~' -f 2)
if [[ "${sqlcmd_result}" = "" ]]; then
  echo "Unable to connect to the target database using ${connect_string}.  Please verify the connection information and target database status."
  exit 255
fi

retval=$?


extractorVersion="$(get_version)"

echo ""
echo "==================================================================================="
echo "Database Migration Assessment Database Assessment Collector Version ${dma_version}"
print_extractor_version "${extractorVersion}"
echo "==================================================================================="

if [ $retval -eq 0 ]; then
  if [ "$(echo ${sqlcmd_result} | $grep_cmd -E '(ORA-|SP2-)')" != "" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database version check returned error ${sqlcmd_result}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Exiting...."
    exit 255
  else
    echo "Your database version is $(echo ${sqlcmd_result} | cut -d '|' -f1)"
    dbmajor=$((echo ${sqlcmd_result} | cut -d '|' -f1)  |cut -d '.' -f 1)
    if [ "${dbmajor}" = "10" ]; then
      echo "Oracle 10 support is experimental."
    else
      if [ "${dbmajor}" = "09" ]; then
        echo "Oracle 9 support is experimental."
        DIAGPACKACCESS="NoDiagnostics"
      fi
    fi
    V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).csv"; export V_TAG
    execute_dma "${connect_string}" ${dma_version} ${DIAGPACKACCESS} "${manualUniqueId}" $statsWindow
    retval=$?
    if [ $retval -ne 0 ]; then
      create_error_log  $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
      compress_dma_files $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database Migration Assessment extract reported an error.  Please check the error log in directory ${log_dir}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Exiting...."
      exit 255
    fi
    create_error_log  $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
    cleanup_dma_output $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g')
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database Migration Assessment data sanitation reported an error. Please check the error log in directory ${output_dir}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Exiting...."
      exit 255
    fi
    dma_id=$(get_dma_source_id ${V_TAG})
    if [[ "${collectOEE}" == "Y" ]]; then
      oeeCheck=$(oeeCheckConditions "${connStr}")
      if [[ "${oeeCheck}" == "PASS" ]] ; then
        oeeGenerateConfig ${dma_id} ${databaseService} ${hostName} ${port} ${collectionUserName} ${collectionUserPass} ${oeeGroup} ${oeeRunId} ${V_TAG}
        if [[ "${dmaAutomation}" != "Y" ]] ; then
          oeeRun "${oeeRunId}"
        fi
      else
        echo "Skipping Estate Explorere collection for ${databaseService} ${hostName}"
      fi
    fi
    compress_dma_files $(echo ${V_TAG} | ${sed_cmd} 's/.csv//g') $dbType
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database Migration Assessment data file archive encountered a problem.  Exiting...."
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      exit 255
    fi
    echo ""
    echo "==================================================================================="
    echo "Database Migration Assessment Database Assessment Collector completed."
    echo "Data collection located at ${output_dir}/${OUTFILE}"
    echo "==================================================================================="
    echo ""
    print_extractor_version "${extractorVersion}"
    exit 0
  fi
else
  echo "Error executing SQL*Plus"
  exit 255
fi
