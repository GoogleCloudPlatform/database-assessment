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

# The default grep command in Solaris does not support the functionality required.  Need the GNU version at /usr/bin/ggrep or /usr/sfw/bin/ggrep.
if [[ "$(uname)" = "SunOS" ]] ; then
  if [[ -f /usr/bin/ggrep ]]; then
    grep_cmd=/usr/bin/ggrep
  else if [[ -f /usr/sfw/bin/ggrep ]]; then
         grep_cmd=/usr/sfw/bin/ggrep
       else
         echo "Solaris requires 'ggrep' (GNU grep) installed in either /usr/bin/ggrep or /usr/sfw/bin/ggrep'. Please install "
         exit 1
       fi
  end if
else
  grep_cmd=$(which grep 2>/dev/null)
fi


function print_status() {
  fail_count=$(${grep_cmd} "DMA:Error creating user" "${dma_log_name}" | wc -l)
  fail_entries=$(${grep_cmd} "DMA:Error creating user"  "${dma_log_name}" | cut -d ' ' -f 7)

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
  while IFS=, read -r sys_user dma_user db stats_source stats_window dma_id oee_flag oee_group || [[ -n "$line" ]]; do
    pass=$(echo ${dma_user} | cut -d '/' -f 2)
    user=$(echo ${dma_user} | cut -d ',' -f 2 | cut -d '/' -f 1)

    echo "Processing user ${dma_user} for database ${db}"
    stats_source=$(echo "$statsrc}" | tr '[a-z]' '[A-Z]')
    if [[ "${stats_source}" = "AWR" ]]
    then
      awr_flag='Y'
    else
      awr_flag='N'
    fi
    ret_cd=-1
    sqlplus "${sys_user}${db} as sysdba" << EOF
SET ECHO ON
SET SERVEROUTPUT ON SIZE 50000;
WHENEVER SQLERROR EXIT FAILURE;
DECLARE cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt
  FROM dba_users
  WHERE username = '${dma_user}';
  IF cnt = 0 THEN
    EXECUTE IMMEDIATE 'CREATE USER "${dma_user}" IDENTIFIED BY "${pass}"';
    DBMS_OUTPUT.PUT_LINE ('Created user "${dma_user}" ');
  ELSE
    DBMS_OUTPUT.PUT_LINE('User "${dma_user}" exists.');
    EXECUTE IMMEDIATE 'ALTER USER "${dma_user}" IDENTIFIED BY "${pass}"';
  END IF;
END;
/
l
GRANT CONNECT, CREATE SESSION to "${dma_user}";
GRANT SELECT ON V_\$DATABASE to "${dma_user}";
exit
EOF

    ret_cd=$?
    if [[ ${ret_cd} -eq 0 ]]
    then
      sqlplus "${sys_user}${db} as sysdba" @sql/setup/grants_wrapper.sql << EOF
${dma_user}
${awr_flag}
${oee_flag}
EOF
      ret_cd=$?
    fi
    if [[ ${ret_cd} -ne 0 ]]
    then
      echo "DMA:Error creating user ${dma_user} in database ${db}."
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
