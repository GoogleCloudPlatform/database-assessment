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
OpVersion="4.3.15"

LOCALE=$(echo $LANG | cut -d '.' -f 1)
export LANG=C
export LANG=${LOCALE}.UTF-8

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SQLCMD=mysql
OUTPUT_DIR=${SCRIPT_DIR}/output; export OUTPUT_DIR
SQLOUTPUT_DIR=${OUTPUT_DIR}; export SQLOUTPUT_DIR
ORACLE_PATH=${SCRIPT_DIR}; export ORACLE_PATH
TMP_DIR=${SCRIPT_DIR}/tmp
LOG_DIR=${SCRIPT_DIR}/log
SQL_DIR=${SCRIPT_DIR}/sql
DBTYPE=""

GREP=$(which grep)
SED=$(which sed)
if [ $(uname) = "SunOS" ]
then
      GREP=/usr/xpg4/bin/grep
      SED=/usr/xpg4/bin/sed
fi

ZIP=$(which zip 2>/dev/null)
if [ "${ZIP}" = "" ]
 then
  GZIP=$(which gzip 2>/dev/null)
fi

if [ ! -d ${LOG_DIR} ]; then
   mkdir -p ${LOG_DIR}
fi
if [ ! -d ${OUTPUT_DIR} ]; then
   mkdir -p ${OUTPUT_DIR}
fi


function checkPlatform {

 if [ "$1" == "oracle" ];
 then SQLCMD=sqlplus
 else if [ "$1" == "mysql" ];
 then SQLCMD=mysql
  else if [ "$1" == "postgres" ];
    then SQLCMD=psql
    fi
 fi
 fi

 # Check if running on Windows Subsystem for Linux
 ISWIN=$(uname -a | grep -i microsoft |wc -l)
 if [ ${ISWIN} -eq 1 ]
    then
      SQL_DIR=$(wslpath -a -w ${SCRIPT_DIR})/sql
      SQLOUTPUT_DIR=$(wslpath -a -w ${SQLOUTPUT_DIR})
      
      if [ ! "${1}" == "postgres" ]
        then
           SQLCMD=${SQLCMD}.exe
      fi
 fi

 # Check if running on Cygwin
 ISCYG=$(uname -a | grep Cygwin | wc -l)
 if [ ${ISCYG} -eq 1 ]
   then
      SQL_DIR=$(cygpath -w ${SCRIPT_DIR})/sql
      SQLOUTPUT_DIR=$(cygpath -w ${SQLOUTPUT_DIR})
      SQLCMD=${SQLCMD}.exe
 fi
}

### Import logging & helper functions
#############################################################################
function checkVersionPg {
    connectString="$1"
    OpVersion=$2
    user=$(echo ${connectString} | cut -d '/' -f 1)
    pass=$(echo ${connectString} | cut -d '/' -f 2 | cut -d '@' -f 1)
    host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
    port=$(echo ${connectString} | cut -d ':' -f 2 | cut -d '/' -f 1)
    db=$(echo ${connectString} | cut -d '/' -f 5)

    export PGPASSWORD="${pass}"
    if ! [ -x "$(command -v ${SQLCMD})" ]; then
      echo "Could not find ${SQLCMD} command. Source in environment and try again"
      echo "Exiting..."
      exit 1
    fi

    # SELECT 'DMAFILETAG~' , version();
    dbversion=$(${SQLCMD}  --user=$user --password -h $host -w -p $port -t << EOF
SELECT current_setting('server_version');
EOF
)
echo 'DMAFILETAG~'${dbversion}'|'${dbversion}'_'${OpVersion}'_'${host}'-'${port}'_'${db}'_'${db}
}

function checkVersionMysql {
    connectString="$1"
    OpVersion=$2
    user=$(echo ${connectString} | cut -d '/' -f 1)
    pass=$(echo ${connectString} | cut -d '/' -f 2 | cut -d '@' -f 1)
    host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
    port=$(echo ${connectString} | cut -d ':' -f 2 | cut -d '/' -f 1)
    db=$(echo ${connectString} | cut -d '/' -f 5)

    echo $user $pass $host $port $db

    if ! [ -x "$(command -v ${SQLCMD})" ]; then
      echo "Could not find ${SQLCMD} command. Source in environment and try again"
      echo "Exiting..."
      exit 1
    fi

# SELECT 'DMAFILETAG~' , version();
dbversion=$(${SQLCMD}  --user=$user --password=$pass -h $host -P $port -s $db << EOF
SELECT version();
EOF
)
echo 'DMAFILETAG~'${dbversion}'|'${dbversion}'_'${OpVersion}'_'${host}'-'${port}'_'${db}'_'${db}'_'$(date +%y%m%d%H%M%S)
}


function checkVersionOracle {
connectString="$1"
OpVersion=$2

if ! [ -x "$(command -v ${SQLCMD})" ]; then
  echo "Could not find ${SQLCMD} command. Source in environment and try again"
  echo "Exiting..."
  exit 1
fi

${SQLCMD} -s /nolog << EOF
connect ${connectString}
@${SQL_DIR}/op_set_sql_env.sql
set pagesize 0 lines 400 feedback off verify off heading off echo off timing off time off
column vname new_value v_name noprint
select min(object_name) as vname from dba_objects where object_name in ('V\$INSTANCE', 'GV\$INSTANCE');
select 'DMAFILETAG~'|| i.version||'|'||substr(replace(i.version,'.',''),0,3)||'_'||'${OpVersion}_'||i.host_name||'_'||d.name||'_'||i.instance_name||'_'||to_char(sysdate, 'MMDDRRHH24MISS')||'~'
from ( SELECT version, host_name, instance_name FROM &&v_name WHERE instance_number = (SELECT min(instance_number) FROM &&v_name) ) i, v\$database d;
exit;
EOF
}


function executeOPOracle {
connectString="$1"
OpVersion=$2
DiagPack=$(echo $3 | tr [[:upper:]] [[:lower:]])

if ! [ -x "$(command -v ${SQLCMD})" ]; then
  echo "Could not find ${SQLCMD} command. Source in environment and try again"
  echo "Exiting..."
  exit 1
fi


${SQLCMD} -s /nolog << EOF
connect ${connectString}
@${SQL_DIR}/op_collect.sql ${OpVersion} ${SQL_DIR} ${DiagPack} ${V_TAG} ${SQLOUTPUT_DIR}
exit;
EOF

}


function executeOPMysql {
connectString="$1"
OpVersion=$2
V_FILE_TAG=$3
user=$(echo ${connectString} | cut -d '/' -f 1)
pass=$(echo ${connectString} | cut -d '/' -f 2 | cut -d '@' -f 1)
host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
port=$(echo ${connectString} | cut -d ':' -f 2 | cut -d '/' -f 1)
db=$(echo ${connectString} | cut -d '/' -f 5)

if ! [ -x "$(command -v ${SQLCMD})" ]; then
  echo "Could not find ${SQLCMD} command. Source in environment and try again"
  echo "Exiting..."
  exit 1
fi

export SKIPSCHEMA=$(grep -v \# sql/source/skipschema.csv)

for s in sql/source/*sql
do
  fname=$(echo $s | cut -d '/' -f 3)
  ${SED} "s/V_TAG/${V_TAG}/g;s/SKIPSCHEMA/${SKIPSCHEMA}/g;s/SQLOUTPUT_DIR/'${SQLOUTPUT_DIR}'/g" ${s} > sql/${V_FILE_TAG}_${fname}
done

rm sql/${V_TAG}_mysqlcollector.sql
for f in sql/${V_FILE_TAG}_*sql
do
  echo source ${f} >> sql/${V_FILE_TAG}_mysqlcollector.sql
done

${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --table $db < sql/${V_FILE_TAG}_mysqlcollector.sql

}


function executeOPPg {
connectString="$1"
OpVersion=$2
V_FILE_TAG=$3
user=$(echo ${connectString} | cut -d '/' -f 1)
pass=$(echo ${connectString} | cut -d '/' -f 2 | cut -d '@' -f 1)
host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
port=$(echo ${connectString} | cut -d ':' -f 2 | cut -d '/' -f 1)
db=$(echo ${connectString} | cut -d '/' -f 5)

if ! [ -x "$(command -v ${SQLCMD})" ]; then
  echo "Could not find ${SQLCMD} command. Source in environment and try again"
  echo "Exiting..."
  exit 1
fi


DBID=$(${SQLCMD}  --user=$user --password -h $host -w -p $port -t <<EOF
SELECT system_identifier FROM pg_control_system();
EOF
)

${SQLCMD}  --user=$user --password -h $host -w -p $port -t <<EOF
\set VTAG ${V_FILE_TAG}
\set DBID ${DBID}
\i sql/op_collect.sql
EOF
}

function createErrorLog {
V_FILE_TAG=$1
echo "Checking for errors..."
$GREP -E 'SP2-|ORA-' ${OUTPUT_DIR}/opdb__*${V_FILE_TAG}.csv | $GREP -v opatch > ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
retval=$?
if [ ! -f  ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log ]; then
  echo "Error creating error log.  Exiting..."
  return $retval
fi
if [ -f  ${OUTPUT_DIR}/opdb__opatch*${V_FILE_TAG}.csv ]; then
  $GREP 'sys.dbms_qopatch.get_opatch_lsinventory' ${OUTPUT_DIR}/opdb__opatch*${V_FILE_TAG}.csv >> ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
fi
}


function cleanupOpOutput  {
V_FILE_TAG=$1
echo "Preparing files for compression."
for outfile in  ${OUTPUT_DIR}/opdb*${V_FILE_TAG}.csv
do
 if [ -f $outfile ] ; then
  if [ $(uname) = "SunOS" ]
  then
    ${SED}  's/ *\|/\|/g;s/\| */\|/g;/^$/d;/^\+/d;s/^|//g;s/|\r//g'  ${outfile} > sed_${V_FILE_TAG}.tmp
    cp sed_${V_FILE_TAG}.tmp ${outfile}
    rm sed_${V_FILE_TAG}.tmp
  else if [ $(uname) = "AIX" ]
  then
    ${SED}  's/ *\|/\|/g;s/\| */\|/g;/^$/d;;/^\+/d;s/^|//g;s/|\r//g'  ${outfile} > sed_${V_FILE_TAG}.tmp
    cp sed_${V_FILE_TAG}.tmp ${outfile}
    rm sed_${V_FILE_TAG}.tmp
  else
    ${SED} -r 's/[[:space:]]+\|/\|/g;s/\|[[:space:]]+/\|/g;/^$/d;/^\+/d;s/^\|//g;s/\|$//g' ${outfile} > sed_${V_FILE_TAG}.tmp
    cp sed_${V_FILE_TAG}.tmp ${outfile}
    rm sed_${V_FILE_TAG}.tmp
  fi
  fi
 fi
done
}

function compressOpFiles  {
V_FILE_TAG=$1
V_ERR_TAG=""
echo ""
echo "Archiving output files with tag ${V_FILE_TAG}"
CURRENT_WORKING_DIR=$(pwd)
cp ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_errors.log
if [ -f VERSION.txt ]; then
  cp VERSION.txt ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_version.txt
else
  echo "No Version file found" >  ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_version.txt
fi
ERRCNT=$(wc -l < ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_errors.log)
if [[ ${ERRCNT} -ne 0 ]]
then
  V_ERR_TAG="_ERROR"
  retval=1
  echo "Errors reported during collection:"
  cat ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_errors.log
  echo " "
  echo "Please rerun the extract after correcting the error condition."
fi

TARFILE=opdb_${DBTYPE}_${DIAGPACKACCESS}__${V_FILE_TAG}${V_ERR_TAG}.tar
ZIPFILE=opdb_${DBTYPE}_${DIAGPACKACCESS}__${V_FILE_TAG}${V_ERR_TAG}.zip

locale > ${OUTPUT_DIR}/opdb__${V_FILE_TAG}_locale.txt

echo "ZIPFILE: " $ZIPFILE >> ${OUTPUT_DIR}/opdb__defines__${V_FILE_TAG}.csv

cd ${OUTPUT_DIR}
if [ -f opdb__manifest__${V_FILE_TAG}.txt ];
then
  rm opdb__manifest__${V_FILE_TAG}.txt
fi

for file in $(ls -1  opdb*${V_FILE_TAG}.csv opdb*${V_FILE_TAG}*.log opdb*${V_FILE_TAG}*.txt)
do
 MD5=$(md5sum $file | cut -d ' ' -f 1)
 echo "${DBTYPE}|${MD5}|${file}"  >> opdb__manifest__${V_FILE_TAG}.txt
done

if [ ! "${ZIP}" = "" ]
then
  $ZIP $ZIPFILE  opdb*${V_FILE_TAG}.csv opdb*${V_FILE_TAG}*.log opdb*${V_FILE_TAG}*.txt
  OUTFILE=$ZIPFILE
else
  tar cvf $TARFILE  opdb*${V_FILE_TAG}.csv opdb*${V_FILE_TAG}*.log opdb*${V_FILE_TAG}*.txt
  $GZIP $TARFILE
  OUTFILE=${TARFILE}.gz
fi

if [ -f $OUTFILE ]
then
  rm opdb*${V_FILE_TAG}.csv opdb*${V_FILE_TAG}*.log opdb*${V_FILE_TAG}*.txt
fi

cd ${CURRENT_WORKING_DIR}
echo ""
echo "Step completed."
echo ""
return $retval
}

function getVersion  {
  if [ -f VERSION.txt ]; then
   githash=$(cat VERSION.txt | cut -d '(' -f 2 | tr -d ')' )
  else githash="NONE"
  fi
  echo "$githash"
}

function printExtractorVersion
{
if [ "$1" == "NONE" ];
then
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

### Validate input
#############################################################################

if [[  $# -ne 3  || (  "$2" != "UseDiagnostics" && "$2" != "NoDiagnostics" ) ]]
 then
  echo
  echo "You must indicate whether or not to use the Diagnostics Pack views."
  echo "If this database is licensed to use the Diagnostics pack:"
  echo "  $0 $1 UseDiagnostics"
  echo " "
  echo "If this database is NOT licensed to use the Diagnostics pack:"
  echo "  $0 $1 NoDiagnostics"
  echo " "
  exit 1
fi

# MAIN
#############################################################################

DBTYPE="$3"

connectString="$1"

checkPlatform $DBTYPE


if [ "$DBTYPE" == "oracle" ] ; then
  sqlcmd_result=$(checkVersionOracle "${connectString}" "${OpVersion}" | $GREP DMAFILETAG | cut -d '~' -f 2)
  if [[ "${sqlcmd_result}" = "" ]];
    then
      echo "Unable to connect to the target Oracle database using ${connectString}.  Please verify the connection information and target database status."
      exit 255
    fi
  else if [ "$DBTYPE" == "mysql" ] ; then
    sqlcmd_result=$(checkVersionMysql "${connectString}" "${OpVersion}" | $GREP DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r' )
    echo Result=${sqlcmd_result}
    if [[ "${sqlcmd_result}" = "" ]];
      then
      echo "Unable to connect to the target MySQL database using ${connectString}.  Please verify the connection information and target database status."
      exit 255
    fi
    else if [ "$DBTYPE" == "postgres" ] ; then
      sqlcmd_result=$(checkVersionPg "${connectString}" "${OpVersion}" | $GREP DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r' )
      echo Result=${sqlcmd_result}
      if [[ "${sqlcmd_result}" = "" ]];
        then
        echo "Unable to connect to the target Postgres database using ${connectString}.  Please verify the connection information and target database status."
        exit 255
      fi
    fi
  fi
fi

retval=$?

DIAGPACKACCESS="$2"

extractorVersion="$(getVersion)"

echo ""
echo "==================================================================================="
echo "Database Migration Assessment Database Assessment Collector Version ${OpVersion}"
printExtractorVersion "${extractorVersion}"
echo "==================================================================================="

if [ $retval -eq 0 ]; then
  if [ "$(echo ${sqlcmd_result} | $GREP -E '(ORA-|SP2-)')" != "" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database version check returned error ${sqlcmd_result}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Exiting...."
    exit 255
  else
    echo "Your database version is $(echo ${sqlcmd_result} | cut -d '|' -f1)"
    dbmajor=$((echo ${sqlcmd_result} | cut -d '|' -f1)  |cut -d '.' -f 1)
    if [ "${dbmajor}" = "10" ]
    then
       echo "Oracle 10 support is experimental."
    fi
    V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).csv"; export V_TAG
    echo V_TAG = ${V_TAG}

    if [ "$3" == "oracle" ] ; then
      executeOPOracle "${connectString}" ${OpVersion} ${DIAGPACKACCESS}
      retval=$?
    else if [ "$3" == "mysql" ]; then
      executeOPMysql "${connectString}" ${OpVersion} $(echo ${V_TAG} | ${SED} 's/.csv//g')
      retval=$?
    else if [ "$3" == "postgres" ]; then
      executeOPPg "${connectString}" ${OpVersion} $(echo ${V_TAG} | ${SED} 's/.csv//g')
      retval=$?
      fi
    fi
    fi

    if [ $retval -ne 0 ]; then
      createErrorLog  $(echo ${V_TAG} | ${SED} 's/.csv//g')
      compressOpFiles $(echo ${V_TAG} | ${SED} 's/.csv//g')
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database Migration Assessment extract reported an error.  Please check the error log in directory ${LOG_DIR}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Exiting...."
      exit 255
    fi
    createErrorLog  $(echo ${V_TAG} | sed 's/.csv//g')
    cleanupOpOutput $(echo ${V_TAG} | sed 's/.csv//g')
    retval=$?
    if [ $retval -ne 0 ]; then
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Database Migration Assessment data sanitation reported an error. Please check the error log in directory ${OUTPUT_DIR}"
      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
      echo "Exiting...."
      exit 255
    fi
    compressOpFiles $(echo ${V_TAG} | ${SED} 's/.csv//g')
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
    echo "Data collection located at ${OUTPUT_DIR}/${OUTFILE}"
    echo "==================================================================================="
    echo ""
    printExtractorVersion "${extractorVersion}"
    exit 0
  fi
else
  echo "Error executing SQL*Plus"
  exit 255
fi

