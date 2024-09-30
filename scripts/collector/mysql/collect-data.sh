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

### Setup directories needed for execution
#############################################################################
OpVersion="4.3.39"
dbmajor=""

LOCALE=$(echo $LANG | cut -d '.' -f 1)
export LANG=C
export LANG=${LOCALE}.UTF-8

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
SQLCMD=mysql
OUTPUT_DIR=${SCRIPT_DIR}/output; export OUTPUT_DIR
SQLOUTPUT_DIR=${OUTPUT_DIR}; export SQLOUTPUT_DIR
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

 if [ "$1" == "mysql" ];
 then SQLCMD=mysql
 fi

 # Check if running on Windows Subsystem for Linux
 ISWIN=$(uname -a | grep -i microsoft |wc -l)
 if [ ${ISWIN} -eq 1 ]
    then
      SQL_DIR=$(wslpath -a -w ${SCRIPT_DIR})/sql
      SQLOUTPUT_DIR=$(wslpath -a -w ${SQLOUTPUT_DIR})

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
if [ ! -s ${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG} ]; then
  hdr=$(echo ${f} | cut -d '.' -f 1 | rev | cut -d '/' -f 1 | rev)
  cat sql/headers/${hdr}.header > ${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG}
fi
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

if [ ! -s ${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG} ]; then
  hdr=$(echo ${f} | cut -d '.' -f 1 | rev | cut -d '/' -f 1 | rev)
  cat sql/headers/${hdr}.header > ${OUTPUT_DIR}/opdb__mysql_${fname}__${V_TAG}
fi
done

serverHostname=$(${SQLCMD} --user=$user --password=$pass -h $host -P $port --force --silent --skip-column-names $db 2>>${OUTPUT_DIR}/opdb__stderr_${V_FILE_TAG}.log < sql/hostname.sql | tr -d '\r')
serverIPs=$(getent hosts "$serverHostname" | awk '{print $1}' | tr '\n' ',')
hostOut="output/opdb__mysql_db_host_${V_FILE_TAG}.csv"
echo "HOSTNAME|IP_ADDRESSES" > "$hostOut"
echo "\"$serverHostname\"|\"$serverIPs\"" >> "$hostOut"

specsOut="output/opdb__mysql_db_machine_specs_${V_FILE_TAG}.csv"
host=$(echo ${connectString} | cut -d '/' -f 4 | cut -d ':' -f 1)
./db-machine-specs.sh "$host" "$vmUserName" "${V_FILE_TAG}" "${DMA_SOURCE_ID}" "${V_MANUAL_ID}" "${specsOut}" "${extraSSHArgs[@]}"
}


# Check the output files for error messages.
# Slightly different selection criteria for each source.
function createErrorLog {
V_FILE_TAG=$1
echo "Checking for errors..."
        if [ "$DBTYPE" == "mysql" ] ; then
	$GREP -E 'SP2-|ORA-' ${OUTPUT_DIR}/opdb__*${V_FILE_TAG}.csv | $GREP -v opatch > ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log
        retval=$?
        fi
if [ ! -f  ${LOG_DIR}/opdb__${V_FILE_TAG}_errors.log ]; then
	  echo "Error creating error log.  Exiting..."
	    return $retval
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
    ${SED} -r 's/[[:space:]]+\|/\|/g;s/\|[[:space:]]+/\|/g;/^$/d;/^\+/d;s/^\|//g;s/\|$//g;/^(.* row(s)?)/d;' ${outfile} > sed_${V_FILE_TAG}.tmp
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
  echo "https://github.com/GoogleCloudPlatform/database-assessment/releases/latest/download/db-migration-assessment-collection-scripts-mysql.zip"
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

  if [ "$DBTYPE" == "mysql" ] ; then
    sqlcmd_result=$(checkVersionMysql "${connectString}" "${OpVersion}" )
    retval=$?
      if [[ $retval -ne 0 ]];
        then
        echo " "
	      echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        echo "Unable to connect to the target MySQL database using ${connectString}.  Please verify the connection information and target database status."
        echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
        exit 255
      else
	    sqlcmd_result=$(echo "$sqlcmd_result" | $GREP DMAFILETAG | tr -d ' ' | cut -d '~' -f 2 | tr -d '\r' )
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
    V_TAG="$(echo ${sqlcmd_result} | cut -d '|' -f2).csv"; export V_TAG

    if [ "$DBTYPE" == "mysql" ]; then
      executeOPMysql "${connectString}" ${OpVersion} $(echo ${V_TAG} | ${SED} 's/.csv//g') "${manualUniqueId}"
      retval=$?
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
