#!/bin/bash

function checkVersion(){
connectString=$1
version=`sqlplus -s "${connectString}" <<EOF
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
version=`checkVersion "${connectString}"`
echo "Your database version is ${version}"
IFS_bk=`echo ${IFS}`
IFS="."
read -a mainversion <<< "$version"
IFS=`echo ${IFS_bk}`
dbVersion=$(( mainversion[0] + 0 ))

full_path="$(dirname $(realpath $0))"
BASE_DIR=$(/usr/bin/pwd -P); export BASE_DIR
OLD_ORACLE_PATH=${ORACLE_PATH}
ORACLE_PATH=${full_path}; export ORACLE_PATH
SQL_SCRIPT="op_collect.sql"
sqlplus -s ${connectString} @${SQL_SCRIPT}
if [ ! -z "$OLD_ORACLE_PATH" ]; then
  ORACLE_PATH=${OLD_ORACLE_PATH}; export ORACLE_PATH
fi