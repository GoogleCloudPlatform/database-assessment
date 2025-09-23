# This script will parse the contents of the dma_db_list.csv file
# and create the specified users for DMA collection in the
# specified databases.  Output is written to a log file.
# The format of the dma_db_list.csv file is described in the header of that file.
# This script expects to run in bash shell, but should execute in ksh also.
. ./dma_print_pass_fail.sh
LOGNAME=dma_make_user_$(date +%Y%m%d%H%M%S).log
CONFIGFILE=dma_db_list.csv
FAILCOUNT=0
FAILENTRIES=

function printStatus() {
  FAILCOUNT=$(grep "DMA:Error creating user" ${LOGNAME} | wc -l)
  FAILENTRIES=$(grep "DMA:Error creating user"  ${LOGNAME} | cut -d ' ' -f 7)

  if [[ ${FAILCOUNT} -gt 0 ]]
  then
    echo
    print_fail
    echo
    echo Failures encountered = ${FAILCOUNT}
    echo Failures in in:
    for fe in ${FAILENTRIES}
    do
      echo ${fe}
    done
    echo
    echo Please address the errors enountered and retry.
    echo
  else
    print_complete
  fi
}

function makeUser() {
  for x in $(cat "${CONFIGFILE}" | grep -v '^#' | grep -v '^$')
  do
    sys=$(echo $x | cut -d ',' -f 1)
    user=$(echo $x | cut -d ',' -f 2 | cut -d '/' -f 1)
    pass=$(echo $x | cut -d ',' -f 2 | cut -d '/' -f 2)
    db=$(echo $x | cut -d ',' -f 3)
    awr=$(echo $x | cut -d ',' -f 4)
    oracleee=$(echo $x | cut -d ',' -f 7)
    echo Processing user ${user} for database ${db}
    if [ "${awr}" = "AWR" ]
    then
      awr_flag='Y'
    else
      awr_flag='N'
    fi
    retcd=-1
    echo AWR_FLAG set to ${awr_flag}
    echo ORACLEEE set to ${oracleee}
    sqlplus "${sys}${db} as sysdba" << EOF
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
    if [ ${retcd} -eq 0 ]
    then
      sqlplus "${sys}${db} as sysdba" @../sql/setup/grants_wrapper.sql << EOF
${user}
${awr_flag}
${oracleee}
EOF
      retcd=$?
    fi
    if [ ${retcd} -ne 0 ]
    then
      echo "DMA:Error creating user ${user} in database ${db}."
      echo "Please verify the username/password and connection information."
    fi
  done 2>&1 | tee ${LOGNAME}

  printStatus | tee -a ${LOGNAME}
}

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
    CONFIGFILE="${2}"
  else
    echo "Unknown parameter ${1}"
    printUsage
    exit
  fi
  shift 2
done

makeUser
