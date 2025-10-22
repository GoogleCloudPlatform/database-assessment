#!/bin/bash
#
# This script will parse the contents of the dma_db_list.csv file
# and create the specified users for DMA collection in the
# specified databases.  Output is written to a log file.
# The format of the dma_db_list.csv file is described in the header of that file.
#
# Import shared functions
. ./dma_print_pass_fail.sh

# Global variables
dma_log_name=dma_make_user_$(date +%Y%m%d%H%M%S).log
config_file=dma_db_list.csv
fail_count=0
fail_entries=
tab_char=$(printf '\t')


function print_status() {
  fail_count=$(grep "DMA:Error creating user" "${dma_log_name}" | wc -l)
  fail_entries=$(grep "DMA:Error creating user"  "${dma_log_name}" | cut -d ' ' -f 7)

  if [[ "${fail_count}" -gt 0 ]]; then
    echo
    print_fail
    echo
    echo "Failures encountered = ${fail_count}"
    echo "Failures in in:"
    for fe in "${fail_entries}"
    do
      echo "${fe}"
    done
    echo
    echo "Please address the errors enountered and retry."
    echo
  else
    print_complete
  fi
}


function make_user() {
  while IFS=, read -r sysUser user db statssrc statswindow dmaid oee_flag oee_group || [[ -n "$line" ]]; do
    pass=$(echo ${user} | cut -d '/' -f 2)
    user=$(echo ${user} | cut -d ',' -f 2 | cut -d '/' -f 1)

    echo "Processing user ${user} for database ${db}"
    statssrc=$(echo "$statsrc}" | tr '[a-z]' '[A-Z]')
    if [[ "${statssrc}" = "AWR" ]]
    then
      awr_flag='Y'
    else
      awr_flag='N'
    fi
    retcd=-1
    sqlplus "${sysUser}${db} as sysdba" << EOF
SET ECHO ON
SET SERVEROUTPUT ON SIZE 50000;
WHENEVER SQLERROR EXIT FAILURE;
DECLARE cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt
  FROM dba_users
  WHERE username = '${user}';
  IF cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER "${user}" IDENTIFIED BY "${pass}"';
    DBMS_OUTPUT.PUT_LINE ('Created user "${user}" ');
  ELSE
    DBMS_OUTPUT.PUT_LINE('User "${user}" exists.');
    EXECUTE IMMEDIATE 'ALTER USER "${user}" IDENTIFIED BY "${pass}"';
  END IF;
END;
/
l
GRANT CONNECT, CREATE SESSION to "${user}";
GRANT SELECT ON V_\$DATABASE to "${user}";
exit
EOF

    retcd=$?
    if [[ ${retcd} -eq 0 ]]
    then
      sqlplus "${sysUser}${db} as sysdba" @sql/setup/grants_wrapper.sql << EOF
${user}
${awr_flag}
${oee_flag}
EOF
      retcd=$?
    fi
    if [[ ${retcd} -ne 0 ]]
    then
      echo "DMA:Error creating user ${user} in database ${db}."
      echo "Please verify the username/password and connection information."
    fi
  done < <( tr -d ' ' < "${config_file}" | tr -d "${tab_char}" | grep -v '^#' | grep -v '^$' )  2>&1 | tee "${dma_log_name}"

  print_status | tee -a ${dma_log_name}
}


function main() {
  ### Validate input
  if [[ $(($# & 1)) == 1 ]] ;
  then
    echo "Invalid number of parameters "
    printUsage
    exit
  fi
  
  while (( "$#" )); do
    if [[ "$1" == "--configFile" ]];
    then
      config_file="${2}"
    else
      echo "Unknown parameter ${1}"
      printUsage
      exit
    fi
    shift 2
  done

  make_user
}


main "$@"
