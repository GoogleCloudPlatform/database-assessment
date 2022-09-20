#!/bin/bash

### Setup directories needed for execution
#############################################################################

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
BASE_DIR=$(dirname ${SCRIPT_DIR}); export BASE_DIR
OP_OUTPUT_DIR=${BASE_DIR}/op_output; export OP_OUTPUT_DIR
ORACLE_PATH=${BASE_DIR}/db_assessment/dbSQLCollector; export ORACLE_PATH

### Import logging & helper functions
#############################################################################

function checkVersion(){
connectString=$1
OpVersion=$(cat ${BASE_DIR}/version | head -1)

if ! [ -x "$(command -v sqlplus)" ]; then
  error 'could not find sqlplus command.'
fi

sqlplus -s /nolog << EOF
set pagesize 0 feedback off verify off heading off echo off
connect ${connectString}
select i.version||'|'||substr(replace(i.version,'.',''),0,3)||'_'||'${OpVersion}_'||i.host_name||'_'||d.name||'_'||i.instance_name||'_'||to_char(sysdate,'MMDDRRHH24MISS')
from v\$instance i, v\$database d;
exit;
EOF
}

function executeOP(){
connectString=$1

if ! [ -x "$(command -v sqlplus)" ]; then
  error 'could not find sqlplus command.'
fi

sqlplus -s /nolog << EOF
connect ${connectString}
@${BASE_DIR}/db_assessment/dbSQLCollector/op_collect.sql
exit;
EOF
}

function cleanupOpOutput(){
echo "Preparing files for compression."
sed -i -r -f ${BASE_DIR}/db_assessment/dbSQLCollector/op_sed_cleanup.sed ${OP_OUTPUT_DIR}/*log
sed -i -r '1i\ ' ${OP_OUTPUT_DIR}/*log
grep -E 'SP2-|ORA-' ${OP_OUTPUT_DIR}/opdb__*log > ${OP_OUTPUT_DIR}/errors.log
}

function compressOpFiles(){
V_FILE_TAG=$1
echo ""
echo "Archiving output files"
CURRENT_WORKING_DIR=$(pwd)
cd ${OP_OUTPUT_DIR}; tar czf opdb__${V_FILE_TAG}.tgz --remove-files *log
cd ${CURRENT_WORKING_DIR}
echo ""
echo "Step completed."
echo ""
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

connectString=$1
sqlcmd_result=$(checkVersion "${connectString}")
retval=$?

echo ""
echo "==================================================================================="
echo "Optimus Prime Database Assessment Collector Version $(cat ${BASE_DIR}/version | head -1)"
echo "==================================================================================="

if [ $retval -eq 0 ]; then
  if [ "$(echo "${sqlcmd_result}" | grep -E '(ORA-|SP2-)')" != "" ]; then
    echo "Database version check returned error ${sqlcmd_result}"
    echo "Exiting...."
    exit 255
  else
    echo "Your database version is $(echo ${sqlcmd_result} | cut -d '|' -f1)"
    V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).log"; export V_TAG
    executeOP ${connectString}
    if [ $retval -ne 0 ]; then
      echo "Optimus Prime extract reported an error.  Please check the error log in directory ${OP_OUTPUT_DIR}"
      echo "Exiting...."
      exit 255
    fi
    cleanupOpOutput
    if [ $retval -ne 0 ]; then
      echo "Optimus Prime data sanitation reported an error. Please check the error log in directory ${OP_OUTPUT_DIR}"
      echo "Exiting...."
      exit 255
    fi
    compressOpFiles $(echo ${V_TAG} | sed 's/.log//g')
    if [ $retval -ne 0 ]; then
      echo "Optimus Prime data file archive encountered a problem.  Exiting...."
      exit 255
    fi
    echo ""
    echo "==================================================================================="
    echo "Optimus Prime Database Assessment Collector completed."
    echo "==================================================================================="
    echo ""
  fi
else
  echo "Error executing SQL*Plus"
  exit 255
fi
