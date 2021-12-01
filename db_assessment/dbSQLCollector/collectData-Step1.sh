#!/bin/bash

function checkVersion(){
connectString=$1
version=`sqlplus -s ${connectString} <<EOF
set pagesize 0 feedback off verify off heading off echo off
select version from v\\$instance;
exit;
EOF`
echo ${version}
}

#main
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <connect string>" >&2
  echo "example: $0 scott/tiger@myoraclehost:1521/myservice"
  exit 1
fi
connectString=$1
version=`checkVersion ${connectString}`
echo "Your database version is ${version}"
IFS_bk=`echo ${IFS}`
IFS="."
read -a mainversion <<< "$version"
IFS=`echo ${IFS_bk}`
dbVersion=$(( mainversion[0] + 0 ))

full_path="$(dirname $(realpath $0))"
SQL_SCRIPT=${full_path}
if [ ${dbVersion} -ge 12 ]; then
echo "running oracle_db_assessment_12c_AND_ABOVE.sql"
SQL_SCRIPT="${SQL_SCRIPT}/oracle_db_assessment_12c_AND_ABOVE.sql"
else
echo "running oracle_db_assessment_ONLY_FOR_11g.sql"
SQL_SCRIPT="${SQL_SCRIPT}/oracle_db_assessment_ONLY_FOR_11g.sql"
fi
sqlplus -s ${connectString} <<EOF
@${SQL_SCRIPT}
EOF
