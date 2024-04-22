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
OpVersion="4.3.34"
dbmajor=""

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
MD5SUM=$(which md5sum)
MD5COL=1

if [ "$(uname)" = "SunOS" ]
then
      GREP=/usr/xpg4/bin/grep
      SED=/usr/xpg4/bin/sed
fi

if [ "$(uname)" = "HP-UX" ]; then
  if [ -f /usr/local/bin/md5 ]; then
    MD5SUM=/usr/local/bin/md5
    MD5COL=4
  fi
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

      if [ "${1}" == "oracle" ]
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
    dbVersion=$(PGPASSWORD="$pass" ${SQLCMD} -X --user=$user -h $host -w -p $port -d "${db}" -t --no-align  2>&1 << EOF
SELECT current_setting('server_version_num');
EOF
)
retcd=$?
    if [[ $retcd -ne 0 ]]
    then
	    echo "Error connecting to the target database ${connectString} ."
	    echo "Connection attempt returned : ${dbVersion}"
	    return $retcd
    fi

    echo 'DMAFILETAG~'${dbVersion}'|'${dbVersion}'_'${OpVersion}'_'${host}'-'${port}'_'${db}'_'${db}'_'$(date +%y%m%d%H%M%S)
}

function checkVersionMysql {
    connectString="$1"
    OpVersion=$2
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

dbVersion=$(${SQLCMD}  --user=$user --password=$pass -h $host -P $port -s $db << EOF
SELECT version();
EOF
)
retcd=$?
    if [[ $retcd -ne 0 ]]
    then
	    echo "Error connecting to the target database ${connectString} ."
	    echo "Connection attempt returned : ${dbVersion}"
	    return $retcd
    fi
echo 'DMAFILETAG~'${dbVersion}'|'${dbVersion}'_'${OpVersion}'_'${host}'-'${port}'_'${db}'_'${db}'_'$(date +%y%m%d%H%M%S)
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
select 'DMAFILETAG~'|| i.version||'|'||substr(replace(i.version,'.',''),0,3)||'_'||'${OpVersion}_'||i.host_name||'_'||d.name||'_'||i.instance_name||'_'||to_char(sysdate,'MMDDRRHH24MISS')||'~'
from ( SELECT case when version like '9%' then '0' || version else version end as version, host_name, instance_name FROM &&v_name WHERE instance_number = (SELECT min(instance_number) FROM &&v_name) ) i, v\$database d;
exit;
EOF
}


function executeOPOracle {
connectString="$1"
OpVersion=$2
DiagPack=$(echo $3 | tr [[:upper:]] [[:lower:]])
manualUniqueId="${4}"

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
V_MANUAL_ID="${4}"
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

export DMA_SOURCE_ID=$(${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --silent --skip-column-names $db 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log < sql/init.sql | tr -d '\r')
export SCRIPT_PATH=$(${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --silent --skip-column-names $db 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log < sql/_base_path_lookup.sql | tr -d '\r')

for f in $(ls -1 sql/*.sql | grep -v -e init.sql | grep -v -e _base_path_lookup.sql)
do
  fname=$(echo ${f} | cut -d '/' -f 2 | cut -d '.' -f 1)
    ${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --table  ${db} >${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG} 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log  <<EOF
SET @DMA_SOURCE_ID='${DMA_SOURCE_ID}' ;
SET @DMA_MANUAL_ID='${V_MANUAL_ID}' ;
SET @PKEY='${V_FILE_TAG}';
source ${f}
exit
EOF
done
for f in $(ls -1 sql/${SCRIPT_PATH}/*.sql | grep -v -E "init.sql|_base_path_lookup.sql|hostname.sql")
do
  fname=$(echo ${f} | cut -d '/' -f 3 | cut -d '.' -f 1)
    ${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --table  ${db} >${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG} 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log  <<EOF
SET @DMA_SOURCE_ID='${DMA_SOURCE_ID}' ; 
SET @DMA_MANUAL_ID='${V_MANUAL_ID}' ;
SET @PKEY='${V_FILE_TAG}';
source ${f}
exit
EOF

serverHostname=$(${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --silent --skip-column-names $db 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log < sql/hostname.sql | tr -d '\r')
serverIPs=$(getent hosts "$serverHostname" | awk '{print $1}' | tr '\n' ',')
hostOut="output/opdb__mysql_db_host_${V_FILE_TAG}.csv"
echo "HOSTNAME|IP_ADDRESSES" > "$hostOut"
echo "\"$serverHostname\"|\"$serverIPs\"" >> "$hostOut"
done

specsOut="output/opdb__mysql_db_machine_specs_${V_FILE_TAG}.csv"
host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
./db-machine-specs.sh "$host" "$vmUserName" "${V_FILE_TAG}" "${DMA_SOURCE_ID}" "${V_MANUAL_ID}" "${specsOut}" "${extraSSHArgs[@]}"
}

function executeOPPg {
connectString="$1"
OpVersion=$2
V_FILE_TAG=$3
V_MANUAL_ID="${4}"
allDbs="${5}"
user=$(echo "${connectString}" | cut -d '/' -f 1)
pass=$(echo "${connectString}" | cut -d '/' -f 2 | cut -d '@' -f 1)
host=$(echo "${connectString}" | cut -d '/' -f 4 | cut -d ':' -f 1)
port=$(echo "${connectString}" | cut -d ':' -f 2 | cut -d '/' -f 1)
db=$(echo "${connectString}" | cut -d '/' -f 5)

if ! [ -x "$(command -v ${SQLCMD})" ]; then
  echo "Could not find ${SQLCMD} command. Source in environment and try again"
  echo "Exiting..."
  exit 1
fi


DMA_SOURCE_ID=$(PGPASSWORD="$pass" ${SQLCMD} -X --user=$user  -h $host -w -p $port -d "$db" -t --no-align <<EOF
SELECT system_identifier FROM pg_control_system();
EOF
)


if [[ "${V_MANUAL_ID}" == "" ]]
then
	V_MANUAL_ID="NA"
fi

if [[ "${DMA_SOURCE_ID}" == "" ]]
then
	DMA_SOURCE_ID="NA"
fi

# Only run once per VM, instead of once per DB.
specsOut="output/opdb__pg_db_machine_specs_${V_FILE_TAG}.csv"
if [[ -z "$specsPath" ]] ; then
      host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
      ./db-machine-specs.sh "$host" "$vmUserName" "${V_FILE_TAG}" "${DMA_SOURCE_ID}" "${V_MANUAL_ID}" "${specsOut}" "${extraSSHArgs[@]}"
else
	if [[ -f "$specsPath" ]]; then
           mv "$specsPath" "$specsOut"
	fi
fi

# If allDbs = "Y" loop through all the databases in the instance and create a collection for each one, then exit.
if [[ "${allDbs}" == "Y" ]] ;
then
      export OLDIFS=$IFS
      dblist=$(PGPASSWORD="${pass}" ${SQLCMD}  --user=$user  -h $host -w -p $port -d "${db}" -t --no-align <<EOF
\l
EOF
)

      IFS=$'\n'
      alldbs=$( for dbentry in ${dblist}
                    do
              	         echo $(echo "${dbentry}" | cut -d '|' -f 1 | cut -d '=' -f 1)
                    done | grep -v -e template0 -e template1 | sort -u)

      # Parse out the unique database names, excluding the templates.  Handle some special characters in the database name.
      for db in ${alldbs}
	do
            export IFS=$OLDIFS
  	    ./collect-data.sh --connectionStr ${user}/${pass}@//${host}:${port}/"${db}"  --manualUniqueId ${V_MANUAL_ID}  --specsPath "$specsOut" --allDbs N
	done
	exit
else
# If given a database name, create a collection for that one database.
export PGPASSWORD="$pass"
${SQLCMD} -X --user=${user} -d "${db}" -h ${host} -w -p ${port}  --no-align --echo-errors 2>output/opdb__stderr_${V_FILE_TAG}.log <<EOF
\set VTAG ${V_FILE_TAG}
\set PKEY '\'${V_FILE_TAG}\''
\set DMA_SOURCE_ID '\'${DMA_SOURCE_ID}\''
\set DMA_MANUAL_ID '\'${V_MANUAL_ID}\''
\i sql/op_collect.sql
EOF

fi
}


# Check the output files for error messages.
# Slightly different selection criteria for each source.
function createErrorLog {
V_FILE_TAG=$1
echo "Checking for errors..."
if [ "$DBTYPE" == "oracle" ] ; then
	$GREP -E 'SP2-|ORA-' ${OUTPUT_DIR}/opdb__*${V_FILE_TAG}.csv | $GREP -v opatch > ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
        else if [ "$DBTYPE" == "mysql" ] ; then
	$GREP -E 'SP2-|ORA-' ${OUTPUT_DIR}/opdb__*${V_FILE_TAG}.csv | $GREP -v opatch > ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
        else if [ "$DBTYPE" == "postgres" ]; then
	$GREP  -i -E 'ERROR:' ${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log > ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
        fi
fi
fi
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
    ${SED} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${V_FILE_TAG}.tmp
    cp sed_${V_FILE_TAG}.tmp ${outfile}
    rm sed_${V_FILE_TAG}.tmp
  else if [ "$(uname)" = "HP-UX" ]
  then
    ${SED} 's/ *\|/\|/g;s/\| */\|/g;/^$/d'  ${outfile} > sed_${V_FILE_TAG}.tmp
    cp sed_${V_FILE_TAG}.tmp ${outfile}
    rm sed_${V_FILE_TAG}.tmp
  else
    ${SED} -r 's/[[:space:]]+\|/\|/g;s/\|[[:space:]]+/\|/g;/^$/d;/^\+/d;s/^\|//g;s/\|$//g;/^(.* row(s)?)/d;1 s/[a-z]/\U&/g' ${outfile} > sed_${V_FILE_TAG}.tmp
    cp sed_${V_FILE_TAG}.tmp ${outfile}
    rm sed_${V_FILE_TAG}.tmp
  fi
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

echo "dbmajor = ${dbmajor}"  >> ${OUTPUT_DIR}/opdb__defines__${V_FILE_TAG}.csv
echo "MANUAL_ID : " ${MANUAL_ID} >> ${OUTPUT_DIR}/opdb__defines__${V_FILE_TAG}.csv
echo "ZIPFILE: " $ZIPFILE >> ${OUTPUT_DIR}/opdb__defines__${V_FILE_TAG}.csv

cd ${OUTPUT_DIR}
if [ -f opdb__manifest__${V_FILE_TAG}.txt ];
then
  rm opdb__manifest__${V_FILE_TAG}.txt
fi

for file in $(ls -1  opdb*${V_FILE_TAG}.csv opdb*${V_FILE_TAG}*.log opdb*${V_FILE_TAG}*.txt)
do
 MD5=$(${MD5SUM} $file | cut -d ' ' -f ${MD5COL})
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


function printUsage()
{
echo " Usage:"
echo "  Parameters"
echo ""
echo "  Connection definition must one of:"
echo "      {"
echo "        --connectionStr       Connection string formatted as {user}/{password}@//{db host}:{listener port}/{service name}"
echo "       or"
echo "        --hostName            Database server host name"
echo "        --port                Database listener port"
echo "        --databaseService     Database service name.  Required."
echo "        --collectionUserName  Database user name."
echo "        --collectionUserPass  Database password"
echo "      }"
echo
echo "  Additional Parameters:"
echo "        --manualUniqueId      (Optional) A short string to be attached to this collection.  Use only when directed."
echo
echo "  VM collection definition (optional):"
echo "        --vmUserName          Username on the VM the Database is running on."
echo "        --extraSSHArg         Extra args to be passed as is to ssh. Can be specified multiple times."
echo
echo " Example:"
echo
echo
echo "  ./collect-data.sh --connectionStr {user}/{password}@//{db host}:{listener port}/{service name}"
echo " or"
echo "  ./collect-data.sh --collectionUserName {user} --collectionUserPass {password} --hostName {db host} --port {listener port} --databaseService {service name}"

}
### Validate input

hostName=""
port=""
databaseService=""
collectionUserName=""
collectionUserPass=""
DBTYPE="mysql"
statsSrc=""
connStr=""
manualUniqueId=""
vmUserName=""
extraSSHArgs=()
specsPath=""

 if [[ $(($# & 1)) == 1 ]] ;
 then
  echo "Invalid number of parameters.  Each parameter must specify a value. "
  printUsage
  exit
 fi

 while (( "$#" )); do
	 if   [[ "$1" == "--hostName" ]];           then hostName="${2}"
	 elif [[ "$1" == "--port" ]];               then port="${2}"
	 elif [[ "$1" == "--databaseService" ]];    then databaseService="${2}"
	 elif [[ "$1" == "--collectionUserName" ]]; then collectionUserName="${2}"
	 elif [[ "$1" == "--collectionUserPass" ]]; then collectionUserPass="${2}"
	 elif [[ "$1" == "--connectionStr" ]];      then connStr="${2}"
	 elif [[ "$1" == "--manualUniqueId" ]];     then manualUniqueId="${2}"
	 elif [[ "$1" == "--vmUserName" ]];         then vmUserName="${2}"
	 elif [[ "$1" == "--extraSSHArg" ]];        then extraSSHArgs+=("${2}")
	 elif [[ "$1" == "--specsPath" ]];          then specsPath=("${2}")
	 else
		 echo "Unknown parameter ${1}"
		 printUsage
		 exit
	 fi
	 shift 2
 done


# if [[ "${dbType}" != "oracle" ]] ; then
#	 dbType="oracle"
# fi

DIAGPACKACCESS="mysql"

 if [[ "${connStr}" == "" ]] ; then
	 if [[ "${hostName}" != "" && "${port}" != "" && "${databaseService}" != "" && "${collectionUserName}" != "" && "${collectionUserPass}" != "" ]] ; then
		 connStr="${collectionUserName}/${collectionUserPass}@//${hostName}:${port}/${databaseService}"
	 else
		 echo "Connection information incomplete"
		 printUsage
		 exit
	 fi
 fi


 if [[ "${manualUniqueId}" != "" && "${manualUniqueId}" != "NA" ]] ; then
	 manualUniqueId=$(echo "${manualUniqueId}" | iconv -t ascii//TRANSLIT | sed -E -e 's/[^[:alnum:]]+/-/g' -e 's/^-+|-+$//g' | tr '[:upper:]' '[:lower:]' | cut -c 1-100)
 else manualUniqueId='NA'

 fi

#############################################################################

# if [[  $# -lt 3  || $# -gt 4 || (  "$2" != "UseDiagnostics" && "$2" != "NoDiagnostics" ) ]]
 #  then
  #   echo
  #   echo "You must indicate whether or not to use the Diagnostics Pack views."
  #   echo "If this database is licensed to use the Diagnostics pack:"
  #   echo "  $0 $1 UseDiagnostics"
  #   echo " "
  #   echo "If this database is NOT licensed to use the Diagnostics pack:"
  #   echo "  $0 $1 NoDiagnostics"
  #   echo " "
  #   exit 1
# fi

# MAIN
#############################################################################

connectString="${connStr}"

checkPlatform $DBTYPE

if [ "$DBTYPE" == "oracle" ] ; then
  sqlcmd_result=$(checkVersionOracle "${connectString}" "${OpVersion}" | $GREP DMAFILETAG | cut -d '~' -f 2)
  retval=$?
  if [[ "${sqlcmd_result}" == "" ]];
    then
      echo "Unable to connect to the target Oracle database using ${connectString}.  Please verify the connection information and target database status."
      exit 255
    fi
  else if [ "$DBTYPE" == "mysql" ] ; then
    sqlcmd_result=$(checkVersionMysql "${connectString}" "${OpVersion}" )
    retval=$?
      if [[ $retval -ne 0 ]];
        then
        echo " "
	      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Unable to connect to the target Postgres database using ${connectString}.  Please verify the connection information and target database status."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 255
      else
	    sqlcmd_result=$(echo "$sqlcmd_result" | $GREP DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r' )
      fi
    else if [ "$DBTYPE" == "postgres" ] ; then
      sqlcmd_result=$(checkVersionPg "${connectString}" "${OpVersion}" )
	    retval=$?
      if [[ $retval -ne 0 ]];
        then
        echo " "
	      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Unable to connect to the target Postgres database using ${connectString}.  Please verify the connection information and target database status."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 255
      else
	    sqlcmd_result=$(echo "$sqlcmd_result" | $GREP DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r' )
      fi
    fi
  fi
fi

extractorVersion="$(getVersion)"

echo ""
echo "==================================================================================="
echo "Database Migration Assessment Database Assessment Collector Version ${OpVersion}"
printExtractorVersion "${extractorVersion}"
echo "==================================================================================="

if [ $retval -eq 0 ]; then
  if [ "$(echo ${sqlcmd_result} | $GREP -E '(ORA-|SP2-|ERROR|FATAL)')" != "" ]; then
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Database version check returned error ${sqlcmd_result}"
    echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    echo "Exiting...."
    exit 255
  else
    echo "Your database version is $(echo ${sqlcmd_result} | cut -d '|' -f1)"
    dbmajor=$((echo ${sqlcmd_result} | cut -d '|' -f1)  |cut -d '.' -f 1)
    if [ "${dbmajor}" == "10" ]
    then
       echo "Oracle 10 support is experimental."
else if [ "${dbmajor}" == "09" ]
      then
       echo "Oracle 9 support is experimental."
       DIAGPACKACCESS="NoDiagnostics"
      fi
    fi
    V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).csv"; export V_TAG

    if [ "$DBTYPE" == "oracle" ] ; then
      executeOPOracle "${connectString}" ${OpVersion} ${DIAGPACKACCESS} "${manualUniqueId}"
      retval=$?
    else if [ "$DBTYPE" == "mysql" ]; then
      executeOPMysql "${connectString}" ${OpVersion} $(echo ${V_TAG} | ${SED} 's/.csv//g') "${manualUniqueId}"
      retval=$?
    else if [ "$DBTYPE" == "postgres" ]; then
      executeOPPg "${connectString}" ${OpVersion} $(echo ${V_TAG} | ${SED} 's/.csv//g') "${manualUniqueId}" "${allDbs}"
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
