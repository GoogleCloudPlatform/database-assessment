#!/usr/bin/env bash
# Copyright 2022 Google LLC
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

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
OUTPUT_DIR=${SCRIPT_DIR}/output; export OUTPUT_DIR
ORACLE_PATH=${SCRIPT_DIR}; export ORACLE_PATH
TMP_DIR=${SCRIPT_DIR}/tmp
LOG_DIR=${SCRIPT_DIR}/log
SQL_DIR=${SCRIPT_DIR}/sql

if [ ! -d ${TMP_DIR} ]; then
   mkdir -p ${LOG_DIR}
fi
if [ ! -d ${LOG_DIR} ]; then
   mkdir -p ${LOG_DIR}
fi
if [ ! -d ${OUTPUT_DIR} ]; then
   mkdir -p ${OUTPUT_DIR}
fi
OpVersion="3.0.8"
### Import logging & helper functions
#############################################################################

function checkVersion(){
connectString="$1"
OpVersion=$2

if ! [ -x "$(command -v sqlplus)" ]; then
  echo "Could not find sqlplus command. Source in environment and try again"
  echo "Exiting..."
fi

sqlplus -s /nolog << EOF
set pagesize 0 lines 400 feedback off verify off heading off echo off
connect ${connectString}
select i.version||'|'||substr(replace(i.version,'.',''),0,3)||'_'||'${OpVersion}_'||i.host_name||'_'||d.name||'_'||i.instance_name||'_'||to_char(sysdate,'MMDDRRHH24MISS')
from v\$instance i, v\$database d;
exit;
EOF
}

function executeOP(){
connectString="$1"
OpVersion=$2

if ! [ -x "$(command -v sqlplus)" ]; then
  echo "Could not find sqlplus command. Source in environment and try again"
  echo "Exiting..."
fi

sqlplus -s /nolog << EOF
connect ${connectString}
@${SCRIPT_DIR}/sql/op_collect.sql ${OpVersion} ${SQL_DIR}
exit;
EOF
}

function cleanupOpOutput(){
V_FILE_TAG=$1
echo "Preparing files for compression."
sed -i -r -f ${SCRIPT_DIR}/sql/op_sed_cleanup.sed ${OUTPUT_DIR}/*csv
retval=$?
if [ $retval -ne 0 ]; then
  echo "Error processing ${SCRIPT_DIR}/sql/op_sed_cleanup.sed.  Exiting..."
  return $retval
fi
sed -i -r '1i\ ' ${OUTPUT_DIR}/*csv
retval=$?
if [ $retval -ne 0 ]; then
  echo "Error adding newline to top of Optimus Prime extract files.  Exiting..."
  return $retval
fi
grep -E 'SP2-|ORA-' ${OUTPUT_DIR}/opdb__*csv > ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
retval=$?
if [ $retval -eq 1 ]; then 
  retval=0
fi
if [ $retval -gt 1 ]; then
  echo "Error creating error log.  Exiting..."
  return $retval
fi
}

function compressOpFiles(){
V_FILE_TAG=$1
V_ERR_TAG=""
echo ""
echo "Archiving output files"
CURRENT_WORKING_DIR=$(pwd)
cp ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_errors.log
ERRCNT=$(wc -l < ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_errors.log)
if [[ ${ERRCNT} -ne 0 ]]
then
  V_ERR_TAG="_ERROR"
  retval=1
fi

cd ${OUTPUT_DIR}; tar czf opdb__${V_FILE_TAG}${V_ERR_TAG}.tgz --remove-files *csv *.log
cd ${CURRENT_WORKING_DIR}
echo ""
echo "Step completed."
echo ""
return $retval
}

### Validate input
#############################################################################

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <connect string>" >&2
  echo "example: $0 scott/tiger@myoraclehost:1521/myservice"
  exit 1
fi


# MAIN
#############################################################################

connectString="$1"
sqlcmd_result=$(checkVersion "${connectString}" "${OpVersion}")
retval=$?

echo ""
echo "==================================================================================="
echo "Optimus Prime Database Assessment Collector Version ${OpVersion}"
echo "==================================================================================="

if [ $retval -eq 0 ]; then
  if [ "$(echo ${sqlcmd_result} | grep -E '(ORA-|SP2-)')" != "" ]; then
    echo "Database version check returned error ${sqlcmd_result}"
    echo "Exiting...."
    exit 255
  else
    echo "Your database version is $(echo ${sqlcmd_result} | cut -d '|' -f1)"
    V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).csv"; export V_TAG
    executeOP "${connectString}" ${OpVersion}
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "Optimus Prime extract reported an error.  Please check the error log in directory ${OUTPUT_DIR}"
      echo "Exiting...."
      exit 255
    fi
    cleanupOpOutput $(echo ${V_TAG} | sed 's/.csv//g')
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "Optimus Prime data sanitation reported an error. Please check the error log in directory ${OUTPUT_DIR}"
      echo "Exiting...."
      exit 255
    fi
    compressOpFiles $(echo ${V_TAG} | sed 's/.csv//g')
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "Optimus Prime data file archive encountered a problem.  Exiting...."
      exit 255
    fi
    echo ""
    echo "==================================================================================="
    echo "Optimus Prime Database Assessment Collector completed."
    echo "Data collection located at ${OUTPUT_DIR}/opdb__${V_FILE_TAG}.tgz"
    echo "==================================================================================="
    echo ""
    exit 0
  fi
else
  echo "Error executing SQL*Plus"
  exit 255
fi
