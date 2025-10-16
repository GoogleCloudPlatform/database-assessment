# This script will verify that all the OS commands and utilities are available prior to running the DMA collector.
# Assumes that at least 'which' is available.
. ./dma_print_pass_fail.sh

# TODO Put standardized success / fail into array and print final results.
MINDAYS=7
LOGNAME=dma_precheck_sysdba_$(date +%Y%m%d%H%M%S).log
STATSSRCCOL=4
OEEDIR="$(pwd)/oee"
configfilelinecount=0
TABCHAR=$(printf '\t')

# Check that all required OS commands are available.
function precheckOS() {
  FNAME="${FUNCNAME[0]}"
  echo
  echo Checking for availability of all operating system commands and utilities required for the DMA collector.

  FAIL=0

  # Defaults for Linux
  THISSHELL=${SHELL}
  SCRIPTCOMMAND=${BASH_SOURCE[0]}

  AWK=$(which awk 2>/dev/null)
  CUT=$(which cut 2>/dev/null)
  DIRNAME=$(which dirname 2>/dev/null)
  GREP=$(which grep 2>/dev/null)
  GZIP=$(which gzip 2>/dev/null)
  ICONV=$(which iconv 2>/dev/null)
  MD5SUM=$(which md5sum 2>/dev/null)
  PRINTF=$(which printf 2>/dev/null)
  SED=$(which sed 2>/dev/null)
  SQLPLUS=$(which sqlplus)
  TAR=$(which tar 2>/dev/null)
  TR=$(which tr 2>/dev/null)
  UNAME=$(which uname 2>/dev/null)
  ZIP=$(which zip 2>/dev/null)

  # Override for Solaris
  if [ "$(uname)" = "SunOS" ]; then
    GREP=/usr/xpg4/bin/grep
    SED=/usr/xpg4/bin/sed
  fi

  # Override for HP-UX
  if [ "$(uname)" = "HP-UX" ]; then
    if [ -f /usr/local/bin/md5 ]; then
      MD5SUM=/usr/local/bin/md5
    fi
  fi

  # If BASH_SOURCE is null, assume we are in ksh
  if [ "${SCRIPTCOMMAND}" = "" ]; then
    SCRIPTCOMMAND="${.sh.file}"
  fi

  if [ "${AWK}" = "" ]; then
    echo "FAILED : Missing command awk, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${CUT}" = "" ]; then
    echo "FAILED : Missing command cut, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${DIRNAME}" = "" ]; then
    echo "FAILED : Missing command dirname, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${GREP}" = "" ]; then
    echo "FAILED : Missing command grep, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${MD5SUM}" = "" ]; then
    echo "FAILED : Missing command md5sum, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${PRINTF}" = "" ]; then
    echo "FAILED : Missing command printf, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${SED}" = "" ]; then
    echo "FAILED : Missing command sed, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${ICONV}" = "" ]; then
    echo "FAILED : Missing command iconv, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${TR}" = "" ]; then
    echo "FAILED : Missing command tr, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  if [ "${UNAME}" = "" ]; then
    echo "FAILED : Missing command uname, please install this utility or update the path to include it."
    FAIL=$(($FAIL + 1))
  fi

  # Check for either zip or (gzip and tar)
  if [ "${ZIP}" = "" ]; then
    if [ "${GZIP}" = "" ]; then
      echo "FAILED : There is no zip or gzip available."
      FAIL=$(($FAIL + 1))
    else
      if [ "${TAR}" = "" ]; then
        echo "FAILED : There is no zip available.  Found gzip but no tar. If the system does not have zip installed, it must have tar and gzip."
        FAIL=$(($FAIL + 1))
      else
        echo "NOTICE : There is no zip available, so we will use tar and gzip."
      fi
    fi
  fi

  # Check for SQLPLUS client
  # Check if running on Windows Subsystem for Linux
  ISWIN=$(uname -a | ${GREP} -i microsoft | wc -l)
  if [ ${ISWIN} -eq 1 ]; then
    SQL_DIR=$(wslpath -a -w ${SCRIPT_DIR})/sql
    SQLOUTPUT_DIR=$(wslpath -a -w ${SQLOUTPUT_DIR})
    SQLPLUS=$(which sqlplus.exe 2>/dev/null)
  fi

  # Check if running on Cygwin
  ISCYG=$(uname -a | ${GREP} -i cygwin | wc -l)
  if [ ${ISCYG} -eq 1 ]; then
    SQL_DIR=$(cygpath -w ${SCRIPT_DIR})/sql
    SQLOUTPUT_DIR=$(cygpath -w ${SQLOUTPUT_DIR})
    SQLPLUS=$(which sqlplus.exe 2>/dev/null)
  fi

  if [ "${SQLPLUS}" = "" ]; then
    echo "FAILED : SQL*Plus not found on this machine.  Ensure sqlplus is installed and in the path."
    FAIL=$(($FAIL + 1))
  fi

  if [ ${FAIL} -eq 0 ]; then
    echo
    echo "SUCCESS : All required operating system commands are available."
    echo
    echo
    return 0
  else
    echo
    echo "FAILED : Operating system precheck Failed $FAIL tests".
    echo "         Address the issues above and retry."
    return 1
  fi
}


# Verify that any manual identifiers specified are unique within the configuration file.
function precheckConfigUniqueId() {
  FNAME="${FUNCNAME[0]}"
  print_separator
  unqiuevals=()
  echo "Checking configuration file for unique IDs..."

  linecount=$(cat "${CONFIGFILE}" | tr -d ' ' | tr -d "${TABCHAR}" | ${GREP} -v '^#' | ${GREP} -v '^$' | cut -d ',' -f 6 | ${GREP} -v '^$' | wc -l | tr -d ' ')
  uniquecount=$(cat "${CONFIGFILE}" | tr -d ' ' | tr -d "${TABCHAR}" | ${GREP} -v '^#' | ${GREP} -v '^$' | cut -d ',' -f 6 | ${GREP} -v '^$' | sort | uniq -c | wc -l | tr -d ' ')
  
  if [[ ${linecount} -ne ${uniquecount} ]] ; then
    echo "FAILED : Only $uniquecount out of out of $linecount IDs are unique."
    echo "         These Ids appear more than once in the configuration file : "
    echo "Occurrances Value"
    echo "----------- ------------------------------"
    #cat "${CONFIGFILE}" | ${GREP} -v '^#' | ${GREP} -v '^$' | cut -d ',' -f 6 | ${GREP} -v '^$' | sort | uniq -c | ${GREP} -v ' 1 ' | ${SED} 's/^ *//g' | ${SED} "s/ /${TABCHAR}${TABCHAR}${TABCHAR}/g" | awk '{printf "%11s %s", $1, $2}'
    tr -d ' ' < "${CONFIGFILE}" | tr -d "${TABCHAR}" |  ${GREP} -v '^#' | ${GREP} -v '^$' | cut -d ',' -f 6 | ${GREP} -v '^$' | sort | uniq -c | ${GREP} -v ' 1 '  | awk '{printf "%11s %s", $1, $2}'
    return 1
  else 
    echo "SUCCESS : All databases have unique ids where specified."
  fi
}


# Verify we can process the configuration file.
function precheckConfigFileFormat() {
  FNAME="${FUNCNAME[0]}"
  print_separator

  echo "Checking configuration file format..."
  lineno=0
  failcount=0

  while IFS=, read -r sysUser user db statssrc statswindow dmaid oee_flag oee_group || [[ -n "$line" ]]; do
    lineno=$(( ${lineno} + 1 ))
    [[ ${lineno} -gt ${configfilelinecount} ]] && break   # Break out if we have read all the lines.
  
    # Skip comments and empty lines
    sysUser=$(echo "${sysUser}" | tr -d ' ')
    [[ "${sysUser}" =~ ^# ]] || [[ -z "${sysUser}" ]] && continue

    if [[ $(( ${lineno} % 100 )) -eq 0 ]]; then echo "..Checking line ${line}"; fi
    if [[ "${sysUser}" != "" ]]; then
       dmaid=$(echo "${dmaid}" | tr -d '\n' | tr  -c 'a-zA-Z0-9' '_')

      if [[ "${statssrc}" != "AWR" ]] && [[ "${statssrc}" != "STATSPACK" ]] && [[ "${statssrc}" != "NONE" ]] && [[ "${statssrc}" != "NOSTATS" ]]; then
        echo "FAILED : Invalid entry ${statssrc} for Stats Source on line ${lineno}.  Must be one of (AWR, STATSPACK, NONE, NOSTATS)."
        failcount=$(( $failcount + 1 ))
      fi

      if ( [[ "${statssrc}" = "AWR" ]]  ||  [[ "${statssrc}" = "STATSPACK" ]] )  && ( [[ "${statswindow}" != "7" ]] && [[ "{$statswindow}" != "30" ]] ) ; then
        echo "FAILED : Invalid entry ${statswindow} for Stats Window on line ${lineno}. Must be one of (7, 30)."
        failcount=$(( $failcount + 1 ))
      fi  

      # Check parameters for OEE if given
      if [[ "${oee_flag}" != ""  ]] ; then
        if [[ "${oee_flag}" != "Y" ]] && [[ "${oee_flag}" != "N" ]] ; then
          echo "FAILED : Invalid entry ${oee_flag} for OEE Flag on line ${lineno}. Must be one of (Y, N)."
          failcount=$(( $failcount + 1 ))
        fi

        if [[ "${oee_flag}" = "Y" ]] && [[ ! -f ${OEEDIR}/oee_group_extract-SA.sh ]] ; then
            echo "FAILED : OEE collection is specified on line ${lineno} but the OEE collection files are not installed in ${OEEDIR}.  Either install OEE to the specified location or set this flag to N in the configuration file."
            failcount=$(( $failcount + 1 ))
        fi              
      fi
    fi     
  done < <( ${SED} "s/ //g;s/${TABCHAR}//g" "$CONFIGFILE"  )

  if [[ $failcount -eq 0 ]]; then
    echo "SUCCESS : Configuration file format check."
  fi
  return ${failcount}
}


# Connect to the specified database and verify that the DMA user has access to the stats tables requested and that sufficient stats history is available.
function checkStats() {
  FNAME="${FUNCNAME[0]}"
  FNAME='checkStats'
  ${SQLPLUS} -S  -L /nolog  << EOF
  connect ${1}${2}
  set heading off
  set feedback off
  set trimout on
  set lines 300
  set serveroutput on size 5000
  DECLARE
    retval VARCHAR2(1000);
    statsSrc VARCHAR2(10) := '${3}';
    mindays NUMBER := ${4} ;
    cnt NUMBER := 0;
    numdays NUMBER;
    numsnaps NUMBER;
    snapsperday NUMBER;
    sqlStr VARCHAR2(1000);
    dbconn VARCHAR2(100) := '${2}';
  BEGIN
    IF statsSrc = 'NONE' or statsSrc = 'NOSTATS' THEN
      retval := 'NONE : ' || rpad(substr(dbconn,1,40),40) || ' NO PERFORMANCE STATISTICS WILL BE COLLECTED';
    ELSIF statsSrc = 'AWR' THEN
      BEGIN
        SELECT count(1) INTO cnt FROM all_views WHERE view_name LIKE '%_HIST_SNAPSHOT';
        IF nvl(cnt,0) < 1 THEN
          retval := 'FAILED : ' || rpad(substr(dbconn,1,40),40) || ' User has no permissions to select from the AWR tables.  Please execute the grants_wrapper.sql script for this user.';
        ELSE
          sqlStr := 'SELECT  EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) ) FROM dba_hist_snapshot WHERE begin_interval_time < trunc(sysdate)';
          EXECUTE IMMEDIATE sqlStr INTO numdays;
          IF numdays > 0 THEN
            sqlStr := REPLACE('SELECT CASE WHEN EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) ) >= :mindays THEN ~SUCCESS : ~ ELSE ~WARNING : ~ END || rpad(substr(:dbconn,1,40),40, ~ ~) || ~ AWR        START ~ || to_char( min(begin_interval_time), ~YYYY-MM-DD HH24:MI~) || ~  END ~ || to_char(max(begin_interval_time), ~YYYY-MM-DD HH24:MI~) || ~  #SNAPS ~ || LPAD(count(1),4) || ~  #DAYS ~, EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) )
            , (count(1) / EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) ) )
            FROM dba_hist_snapshot
            WHERE begin_interval_time <= trunc(sysdate)', '~', chr(39));
            EXECUTE IMMEDIATE sqlStr INTO retval, numdays, snapsperday USING mindays, dbconn;
            retval := retval || LPAD(numdays, 4) || '  SnapsPerDay ' || round(snapsperday) ;
          END IF;
          IF numdays < mindays THEN
            retval := retval || ' : Expected at least ' || mindays || ' full calendar days of snapshots, but only ' || numdays || ' day(s) found.';
          ELSE
            IF round(snapsperday) < 20 THEN
              retval := retval || ' : AWR snapshot interval appears to be more than 1 hour between snapshots. Found an average of ' || round(snapsperday,2) || ' snapshots per day and expecting ~ 24.';
            END IF;
          END IF;
        END IF;
      END;
    ELSIF statsSrc = 'STATSPACK' THEN
      SELECT count(1) INTO cnt
      FROM all_tables
      WHERE owner ='PERFSTAT'
        AND table_name IN ('STATS\$OSSTAT', 'STATS\$OSSTATNAME', 'STATS\$SNAPSHOT', 'STATS\$SQL_SUMMARY', 'STATS\$SYSSTAT', 'STATS\$SYSTEM_EVENT', 'STATS\$SYS_TIME_MODEL', 'STATS\$TIME_MODEL_STATNAME');

      IF cnt = 8 THEN
        sqlStr := 'SELECT NVL((max(snap_time) -min(snap_time)),0) , COUNT(1) FROM PERFSTAT.STATS\$SNAPSHOT WHERE snap_time <= (sysdate) AND snap_time >= trunc(sysdate - :mindays)';
        EXECUTE IMMEDIATE sqlStr INTO numdays, numsnaps USING mindays;
        numdays:=NVL(numdays,0);
        IF numdays > 0 THEN
          sqlStr := REPLACE('SELECT CASE WHEN trunc(max(snap_time) -min(snap_time) ) >= :mindays THEN ~SUCCESS : ~ ELSE ~WARNING : ~ END || rpad(substr(:dbconn,1,40),40) || ~ STATSPACK  START ~ || to_char(min(snap_time), ~YYYY-MM-DD HH24:MI~) || ~  END ~ || to_char(max(snap_time), ~YYYY-MM-DD HH24:MI~) || ~  #SNAPS ~ || LPAD(count(1), 4) || ~  #DAYS ~ , to_char(trunc(max(snap_time) -min(snap_time) )) , count(1) / (max(snap_time) -min(snap_time) )
          FROM PERFSTAT.STATS\$SNAPSHOT
          WHERE snap_time <= (sysdate)
          AND snap_time >= trunc(sysdate - :mindays)', '~', chr(39));
          EXECUTE IMMEDIATE sqlStr INTO retval, numdays, snapsperday USING mindays, dbconn, mindays;
          retval := retval || LPAD(numdays,4) || '  SnapsPerDay ' || ROUND(snapsperday);
        ELSE
          IF numsnaps <= 1 OR numdays <= 1 THEN retval := 'FAILED : ' || rpad(substr(dbconn,1,40),40) || ' Not enough snapshots to collect performance data.  Either collect more snapshots or disable stats collection for this database.';
          END IF;
        END IF;
      ELSE
        retval := 'FAILED : ' || rpad(substr(dbconn,1,40),40) || ' Missing access to STATSPACK tables. Expecting 8 tables but found ' || cnt || '.';
      END IF;
      IF numdays < mindays THEN
        retval := retval || ' : Expected at least ' || mindays || ' full calendar days of snapshots, but only ' || numdays || ' day(s) found.';
      ELSE
        IF ROUND(NVL(snapsperday,0)) < 20 THEN
          retval := retval || ' : STATSPACK snapshot interval appears to be more than 1 hour between snapshots. Found an average of ' || round(snapsperday,2) ||' snapshots per day and expecting ~ 24.';
        END IF;
      END IF;
    ELSE
      retval := 'ERROR : ' || dbconn || ' Unrecognized value "' || statsSrc || '" in configuration file.';
    END IF;
    if retval is null then retval := 'UNKNOWN return condition for ' || dbconn; 
    end if;
    dbms_output.put_line(retval);
  END;
/
EOF
}


# Loop through the databases given and check that the stats requested are available.
function precheckStats() {
  FNAME="${FUNCNAME[0]}"
  print_separator

  echo "Checking for performance stats ..."
  echo
  retval=0
  lineno=0
  successes=()
  none=()
  errors=()
  warnings=()
  while IFS=, read -r sysUser user db statssrc statswindow dmaid oee_flag oee_group || [[ -n "$line" ]]; do
    lineno=$(( $lineno + 1 ))
    # Skip comments and empty lines
    [[ $lineno -gt $configfilelinecount ]] && break   # Break out if the last line of the config file is a comment or empty
  
    # Skip comments and empty lines
    sysUser=$(echo "${sysUser}" | tr -d ' ')
    [[ "${sysUser}" =~ ^# ]] || [[ -z "${sysUser}" ]] && continue
    username=$(echo "${user}" | cut -d '/' -f 1)
    echo  "...Checking available performance statistics on database ${db} user ${username} for ${statssrc}"
    retcd=$(checkStats "${user}" "${db}" "${statssrc}" "${statswindow}") 
    success=$(echo "${retcd}" | ${GREP} -e SUCCESS -e NONE -e WARNING | cut -d ' ' -f 1)
    if [ "${success}" = "SUCCESS" ]; then
      successes+=("${retcd}")
    else
      if [ "${success}" = "NONE" ]; then
        none+=("${retcd}")
      else
        if [ "${success}" = "WARNING" ]; then
          warnings+=("${retcd}") 
        else 
          errors+=("${retcd}")
        fi
      fi
    fi
  done < <( ${SED} "s/ //g;s/${TABCHAR}//g" "$CONFIGFILE"  )

  retcd=${#successes[@]}
  echo
  echo "Results : "
  if [ $retcd -gt 0 ]; then
    echo
    echo SUCCESS:  These databases have at least ${statswindow} calendar days of performance statistics available:
    printf '%s\n' "${successes[@]}"
  fi

  retcd=${#none[@]}
  if [ $retcd -gt 0 ]; then
    echo
    echo These databases will not have performance stats collected as the parameter NONE or NOSTATS was given in the configuration file.
    printf '%s\n' "${none[@]}"
  fi

  retcd=${#warnings[@]}
  if [ $retcd -gt 0 ]; then
    echo
    echo These databases do not have the minimum days of stats or snapsshot frequency requested.  Data will still be collected but performance metrics may be incomplete.
    printf '%s\n' "${warnings[@]}"
    retval=2
  fi

  retcd=${#errors[@]}
  if [ $retcd -gt 0 ]; then
    echo
    echo FAILED:  These databases did not pass for the below reasons :
    printf '%s\n' "${errors[@]}"
    return 1
  fi

  return $retval
}


# Verify we can connect as SYSDBA role
function checkSysdbaConnection() {
  sqlplus -s -L /nolog << EOF
  connect ${1}${2} as sysdba
  set heading off
  set feedback off
  set trimout on
  SELECT 'SUCCESS' FROM dual;
EOF
}


# Loop through the databases given an verify we can connect as SYSDBA.
function precheckSysdba() {
  FNAME="${FUNCNAME[0]}"
  print_separator
  echo "Checking SYSDBA connections where needed..."
  echo 
  successes=()
  errors=()
  lineno=0

  while IFS=, read -r sysUser user db statssrc statswindow dmaid oee_flag oee_group || [[ -n "$line" ]]; do
     lineno=$(( $lineno + 1 ))

    [[ $lineno -gt $configfilelinecount ]] && break   # Break out if the last line of the config file is a comment or empty
    sysUser=$(echo "${sysUser}" | tr -d ' ')
    # Skip comments and empty lines
    [[ "${sysUser}" =~ ^# ]] || [[ -z "${sysUser}" ]] && continue
    if [[ "${sysUser}" = "" ]] || [[ "${sysUser}" = "NONE" ]] ; then
      echo " : SUCCESS"
      successes+=("SKIPPED : ${db}")
    else
      echo -n "...Testing SYSDBA connection to database ${db}"
      retcd=$(checkSysdbaConnection "${sysUser}" "${db}" )
      success=$(echo "${retcd}" | ${GREP} SUCCESS)
      if [ "${success}" = "SUCCESS" ]; then
        echo " : SUCCESS"
        successes+=("SUCCESS : ${db}")
      else
        echo " : FAILED"
        echo "${retcd}"
        echo
        errors+=("FAILED : ${db}")
      fi
    fi
  done < <( ${SED} "s/ //g;s/${TABCHAR}//g" "$CONFIGFILE"  )


  # for x in $(cat "${CONFIGFILE}" | ${GREP} -v '^#' | ${GREP} -v '^$'); do
  #   sys=$(echo $x | cut -d ',' -f 1)
  #   db=$(echo $x | cut -d ',' -f 3)
  #   if [[ "${sys}" = "" ]] || [[ "${sys}" = "NONE" ]] ; then
  #     echo " : SUCCESS"
  #     successes+=("SKIPPED : ${db}")
  #   else
  #     echo -n "...Testing SYSDBA connection to database ${db}"
  #     retcd=$(checkSysdbaConnection "${sys}" "${db}" )
  #     success=$(echo "${retcd}" | ${GREP} SUCCESS)
  #     if [ "${success}" = "SUCCESS" ]; then
  #       echo " : SUCCESS"
  #       successes+=("SUCCESS : ${db}")
  #     else
  #       echo " : FAILED"
  #       echo "${retcd}"
  #       echo
  #       errors+=("FAILED : ${db}")
  #     fi
  # fi
  # done 

  PASS=${#successes[@]}
  FAIL=${#errors[@]}

  echo
  echo "RESULTS:"
  if [ ${PASS} -gt 0 ]; then
    echo
    echo "SUCCESSFUL SYSDBA CONNECTIONS:"
    printf '%s\n' "${successes[@]}"
  fi

  if [ ${FAIL} -gt 0 ]; then
    echo
    echo "SYSDBA FAILED CONNECTIONS:"
    printf '%s\n' "${errors[@]}"
    return 1
  else
    echo
    echo "SUCCESS : Sysdba connection precheck passed."
    echo
    echo
  fi
}


# Check that the DMA user is able to connect to the given database.
function checkConnection() {
  FNAME="${FUNCNAME[0]}"
  sqlplus -s -L "${1}${2} " << EOF
  set heading off
  set feedback off
  set trimout on
  SELECT 'SUCCESS' FROM dual;
EOF
}


# Verify the DMA user is able to connect to the target databases.
function precheckUser() {
  FNAME="${FUNCNAME[0]}"
  print_separator
  echo "Checking DMA user connections ..."
  echo
  lineno=0
  successes=()
  errors=()

  while IFS=, read -r sysUser user db statssrc statswindow dmaid oee_flag oee_group || [[ -n "$line" ]]; do
     lineno=$(( ${lineno} + 1 ))
    # Skip comments and empty lines
    [[ $lineno -gt $configfilelinecount ]] && break   # Break out if the last line of the config file is a comment or empty
    sysUser=$(echo "${sysUser}" | tr -d ' ')
    [[ "${sysUser}" =~ ^# ]] || [[ -z "${sysUser}" ]] && continue
    username=$(echo ${user} | cut -d '/' -f 1)
    echo -n "...Testing DMA user connection for user ${username} to database ${db}"
    retcd=$(checkConnection "${user}" "${db}" )
    success=$(echo "${retcd}" | ${GREP} SUCCESS)
    if [ "${success}" = "SUCCESS" ]; then
      echo " : SUCCESS"
      successes+=("SUCCESS : ${db}" )
    else
      echo " : FAILED"
      echo "${retcd}"
      errors+=("${retcd} ${db}")
      echo
    fi

  done < <( ${SED} "s/ //g;s/${TABCHAR}//g" "$CONFIGFILE"  )

  # for x in $(cat "${CONFIGFILE}" | ${GREP} -v '^#' | ${GREP} -v '^$'); do
  #   user=$(echo $x | cut -d ',' -f 2)
  #   username=$(echo ${user} | cut -d '/' -f 1)
  #   db=$(echo $x | cut -d ',' -f 3)
  #   echo -n "...Testing DMA user connection for user ${username} to database ${db}"
  #   retcd=$(checkConnection "${user}" "${db}" )
  #   success=$(echo "${retcd}" | ${GREP} SUCCESS)
  #   if [ "${success}" = "SUCCESS" ]; then
  #     echo " : SUCCESS"
  #     successes+=("SUCCESS : ${db}" )
  #   else
  #     echo " : FAILED"
  #     echo "${retcd}"
  #     errors+=("${retcd} ${db}")
  #     echo
  #   fi
  # done 

  echo
  echo
  echo "RESULTS:"
  echo "SUCCESSFUL CONNECTIONS:"
  printf '%s\n' "${successes[@]}"

  retcd=${#errors[@]}
  if [ $retcd -gt 0 ]; then
    echo
    echo "Overall result:"
    echo
    echo
    echo "=========================================="
    echo
    echo "USER PRECHECK FAILED CONNECTIONS:"
    printf '%s\n' "${errors[@]}"
    return 1
  else
    echo
    echo "User connection precheck passed"
    echo
    echo
  fi
}


function runAllChecks() {
 
  echo
  echo "Starting DMA prechecks..."
  echo
  print_separator
  precheckOS
  retval=$?
  if [[ $retval -eq 0 ]]; then precheckConfigFileFormat; retval=$?; fi
  if [[ $retval -eq 0 ]]; then precheckConfigUniqueId ; retval=$?; fi
  if [[ $retval -eq 0 ]]; then precheckSysdba; retval=$?; fi
  if [[ $retval -eq 0 ]]; then precheckUser; retval=$?; fi
  if [[ $retval -eq 0 ]]; then precheckStats; retval=$?; fi

  print_separator

  print_complete  
  if [[ $retval -eq 0 ]]; then 
    print_pass
    echo "All tests complete.  You may proceed with DMA collection."
    echo
  else if [[ $retval -eq 2 ]]; then
    print_warning
    echo "All tests complete with warnings.  You may proceed with DMA collection, but some data may be missing."
    echo
    else
      print_fail
      echo "Address the failures above and retry. "
      echo
    fi  
  fi
}


### Validate input

if [[ $(($# & 1)) == 1 ]] || [[ $# == 0 ]] ; then
  echo "Invalid number of parameters "
  #printUsage
  exit
fi

while (( "$#" )); do
  if [[ "$1" == "--configFile" ]]; then
    CONFIGFILE="${2}"
  else
    echo "Unknown parameter ${1}"
    #printUsage
    exit
  fi
  shift 2
done

if [ -f "${CONFIGFILE}" ]; then 
  configfilelinecount=$(wc -l <"${CONFIGFILE}")
  echo
  echo "Checking ${configfilelinecount} entries in file ${CONFIGFILE}..."
  runAllChecks 
else
  echo "File not found : ${CONFIGFILE}"
fi

