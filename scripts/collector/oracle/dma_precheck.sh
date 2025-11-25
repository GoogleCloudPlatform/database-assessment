# This script will verify that all the OS commands and utilities are available prior to running the DMA collector.
# Assumes that at least 'which' is available.
. ./dma_print_pass_fail.sh
. ./dma_oee.sh

tab_char=$(printf '\t')
configfilelinecount=0
dma_log_name=dma_precheck_$(date +%Y%m%d%H%M%S).log
min_days=7
oee_dir="$(pwd)/oee"
oee_entries=0
stats_src_col=4
configuration_file=""
verify_user="Y"

# Check that all required OS commands are available.
function precheckOS() {
  fname="${FUNCNAME[0]}"
  echo
  echo Checking for availability of all operating system commands and utilities required for the DMA collector.

  fail_count=0

  # Defaults for Linux
  this_shell=${SHELL}
  script_command=${BASH_SOURCE[0]}
  script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
  awk_cmd=$(which awk 2>/dev/null)
  cut_cmd=$(which cut 2>/dev/null)
  dir_name_cmd=$(which dirname 2>/dev/null)
  grep_cmd=$(which grep 2>/dev/null)
  gzip_cmd=$(which gzip 2>/dev/null)
  iconv_cmd=$(which iconv 2>/dev/null)
  md5sum_cmd=$(which md5sum 2>/dev/null)
  printf_cmd=$(which printf 2>/dev/null)
  sed_cmd=$(which sed 2>/dev/null)
  sqlplus_cmd=$(which sqlplus)
  tar_cmd=$(which tar 2>/dev/null)
  tr_cmd=$(which tr 2>/dev/null)
  uname_cmd=$(which uname 2>/dev/null)
  xargs_cmd=$(which xargs 2>/dev/null)
  zip_cmd=$(which zip 2>/dev/null)

  # Override for Solaris
  if [[ "$(uname)" = "SunOS" ]]; then
    sed_cmd=/usr/xpg4/bin/sed
 
    if [[ -f /usr/bin/ggrep ]]; then
      grep_cmd=/usr/bin/ggrep
    else if [[ -f /usr/sfw/bin/ggrep ]]; then
           grep_cmd=/usr/sfw/bin/ggrep
         else
           grep_cmd=""
         fi 
    fi 
  fi

  # Override for HP-UX
  if [[ "$(uname)" = "HP-UX" ]]; then
    if [[ -f /usr/local/bin/md5 ]]; then
      md5sum_cmd=/usr/local/bin/md5
    fi
  fi

  if [[ "$(uname)" = "AIX" ]];then
    if [[ -f /usr/local/bin/md5 ]];then
      md5sum_cmd=/usr/local/bin/md5
      md5_col=4
    else if [[ -f /usr/bin/csum ]];then
        md5sum_cmd="/usr/bin/csum -h MD5"
        md5_col=1
      fi
    fi
  fi

  # If BASH_SOURCE is null, assume we are in ksh
  if [[ "${script_command}" = "" ]]; then
    script_command="${.sh.file}"
  fi

  if [[ "${awk_cmd}" = "" ]]; then
    echo "FAILED : Missing command awk, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${cut_cmd}" = "" ]]; then
    echo "FAILED : Missing command cut, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${dir_name_cmd}" = "" ]]; then
    echo "FAILED : Missing command dirname, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${grep_cmd}" = "" ]]; then
    if [[ "$(uname)" = "SunOS" ]] ; then
      echo "FAILED : Solaris requires 'ggrep' (GNU grep) installed in either /usr/bin/ggrep or /usr/sfw/bin/ggrep. Please install to continue."
    else
      echo "FAILED : Missing command grep, please install this utility or update the path to include it."
    fi
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${md5sum_cmd}" = "" ]]; then
    echo "FAILED : Missing command md5sum, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${printf_cmd}" = "" ]]; then
    echo "FAILED : Missing command printf, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${sed_cmd}" = "" ]]; then
    echo "FAILED : Missing command sed, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${iconv_cmd}" = "" ]]; then
    echo "FAILED : Missing command iconv, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${tr_cmd}" = "" ]]; then
    echo "FAILED : Missing command tr, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${uname_cmd}" = "" ]]; then
    echo "FAILED : Missing command uname, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  if [[ "${xargs_cmd}" = "" ]]; then
    echo "FAILED : Missing command xargs, please install this utility or update the path to include it."
    fail_count=$(($fail_count + 1))
  fi

  # Check for either zip or (gzip and tar)
  if [[ "${zip_cmd}" = "" ]]; then
    if [[ "${gzip_cmd}" = "" ]]; then
      echo "FAILED : There is no zip or gzip available."
      fail_count=$(($fail_count + 1))
    else
      if [[ "${tar_cmd}" = "" ]]; then
        echo "FAILED : There is no zip available.  Found gzip but no tar. If the system does not have zip installed, it must have tar and gzip."
        fail_count=$(($fail_count + 1))
      else
        echo "NOTICE : There is no zip available, so we will use tar and gzip."
      fi
    fi
  fi

  # Check for sqlplus_cmd client
  # Check if running on Windows Subsystem for Linux
  if [[ $(uname -a | ${grep_cmd} -i -c microsoft ) -eq 1 ]]; then
    sql_dir=$(wslpath -a -w ${script_dir})/sql
    sqlplus_cmd=$(which sqlplus.exe 2>/dev/null)
  fi

  # Check if running on Cygwin
  if [[ $(uname -a | ${grep_cmd} -i -c cygwin ) -eq 1 ]]; then
    sql_dir=$(cygpath -w ${script_dir})/sql
    sqlplus_cmd=$(which sqlplus.exe 2>/dev/null)
  fi

  if [[ "${sqlplus_cmd}" = "" ]]; then
    echo "FAILED : SQL*Plus not found on this machine.  Ensure sqlplus is installed and in the path."
    fail_count=$(($fail_count + 1))
  fi

  if [[ ${fail_count} -eq 0 ]]; then
    echo
    echo "SUCCESS : All required operating system commands are available."
    echo
    echo
    return 0
  else
    echo
    echo "FAILED : Operating system precheck Failed $fail_count tests".
    echo "         Address the issues above and retry."
    return 1
  fi
}


# Verify that any manual identifiers specified are unique within the configuration file.
function precheckConfigUniqueId() {
  fname="${FUNCNAME[0]}"
  print_separator
  unqiuevals=()
  echo "Checking configuration file for unique IDs..."

  linecount=$(cat "${configuration_file}" | tr -d ' ' | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' | cut -d ',' -f 6 | ${grep_cmd} -c -v '^$' | wc -l | tr -d ' ')
  uniquecount=$(cat "${configuration_file}" | tr -d ' ' | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' | cut -d ',' -f 6 | ${grep_cmd} -c -v '^$' | sort | uniq -c | wc -l | tr -d ' ')
  
  if [[ ${linecount} -ne ${uniquecount} ]] ; then
    echo "FAILED : Only $uniquecount out of out of $linecount IDs are unique."
    echo "         These Ids appear more than once in the configuration file : "
    echo "Occurrances Value"
    echo "----------- ------------------------------"
    tr -d ' ' < "${configuration_file}" | tr -d "${tab_char}" |  ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' | cut -d ',' -f 6 | ${grep_cmd} -v '^$' | sort | uniq -c | ${grep_cmd} -v ' 1 '  | awk '{printf "%11s %s", $1, $2}'
    return 1
  else 
    echo "SUCCESS : All databases have unique ids where specified."
  fi
}


# Verify we are on a supported platform for OEE collection
function precheck_oee_platform() {
  fname="${FUNCNAME[0]}"
  print_separator

  echo "Checking Oracle Estate Explorer supported platforms..."

  local ret_val=""
  ret_val="$(oee_check_platform)"

  echo "${ret_val}"

  if [[ "${ret_val}" == "PASS" ]]; then
    return 0
  else 
    return 1
  fi
}


# Verify we can process the configuration file.
function precheckConfigFileFormat() {
  fname="${FUNCNAME[0]}"
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

        if [[ "${oee_flag}" == "Y" ]] ; then
          oee_entries=1
        fi

        if [[ "${oee_flag}" = "Y" ]] && [[ ! -f ${oee_dir}/oee_group_extract-SA.sh ]] ; then
            echo "FAILED : OEE collection is specified on line ${lineno} but the OEE collection files are not installed in ${oee_dir}.  Either install OEE to the specified location or set this flag to N in the configuration file."
            failcount=$(( $failcount + 1 ))
        fi              
      fi

    fi     
  done < <( tr -d ' ' < "${configuration_file}" | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' )
#  done < <( ${sed_cmd} "s/ //g;s/${tab_char}//g" "$configuration_file"  )

  if [[ $failcount -eq 0 ]]; then
    echo "SUCCESS : Configuration file format check."
  fi
  return ${failcount}
}


# Connect to the specified database and verify that the DMA user has access to the stats tables requested and that sufficient stats history is available.
# We do not check for permissions on all tables/views required, just assume that if the grants script was run we have have everything we need.
function checkStats() {
  fname="${FUNCNAME[0]}"
  fname='checkStats'
  ${sqlplus_cmd} -S  -L /nolog  << EOF
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
            sqlStr := REPLACE('SELECT CASE WHEN EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) ) >= :mindays THEN ~SUCCESS : ~ ELSE ~WARNING : ~ END || rpad(substr(:dbconn,1,40),40, ~ ~) || ~ AWR        Star_cmdT ~ || to_char( min(begin_interval_time), ~YYYY-MM-DD HH24:MI~) || ~  END ~ || to_char(max(begin_interval_time), ~YYYY-MM-DD HH24:MI~) || ~  #SNAPS ~ || LPAD(count(1),4) || ~  #DAYS ~, EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) )
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
          sqlStr := REPLACE('SELECT CASE WHEN trunc(max(snap_time) -min(snap_time) ) >= :mindays THEN ~SUCCESS : ~ ELSE ~WARNING : ~ END || rpad(substr(:dbconn,1,40),40) || ~ STATSPACK  Star_cmdT ~ || to_char(min(snap_time), ~YYYY-MM-DD HH24:MI~) || ~  END ~ || to_char(max(snap_time), ~YYYY-MM-DD HH24:MI~) || ~  #SNAPS ~ || LPAD(count(1), 4) || ~  #DAYS ~ , to_char(trunc(max(snap_time) -min(snap_time) )) , count(1) / (max(snap_time) -min(snap_time) )
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
  fname="${FUNCNAME[0]}"
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
    success=$(echo "${retcd}" | ${grep_cmd} -e SUCCESS -e NONE -e WARNING | cut -d ' ' -f 1)
    if [[ "${success}" = "SUCCESS" ]]; then
      successes+=("${retcd}")
    else
      if [[ "${success}" = "NONE" ]]; then
        none+=("${retcd}")
      else
        if [[ "${success}" = "WARNING" ]]; then
          warnings+=("${retcd}") 
        else 
          errors+=("${retcd}")
        fi
      fi
    fi
#  done < <( ${sed_cmd} "s/ //g;s/${tab_char}//g" "$configuration_file"  )
  done < <( tr -d ' ' < "${configuration_file}" | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' )

  retcd=${#successes[@]}
  echo
  echo "Results : "
  if [[ $retcd -gt 0 ]]; then
    echo
    echo SUCCESS:  These databases have at least ${statswindow} calendar days of performance statistics available:
    printf '%s\n' "${successes[@]}"
  fi

  retcd=${#none[@]}
  if [[ $retcd -gt 0 ]]; then
    echo
    echo These databases will not have performance stats collected as the parameter NONE or NOSTATS was given in the configuration file.
    printf '%s\n' "${none[@]}"
  fi

  retcd=${#warnings[@]}
  if [[ $retcd -gt 0 ]]; then
    echo
    echo These databases do not have the minimum days of stats or snapsshot frequency requested.  Data will still be collected but performance metrics may be incomplete.
    printf '%s\n' "${warnings[@]}"
    retval=2
  fi

  retcd=${#errors[@]}
  if [[ $retcd -gt 0 ]]; then
    echo
    echo FAILED:  These databases did not pass for the below reasons :
    printf '%s\n' "${errors[@]}"
    return 1
  fi

  return $retval
}


# Verify we can connect as SYSDBA role
function checkSysdbaConnection() {
  ${sqlplus_cmd} -s -L /nolog << EOF
  connect ${1}${2} as sysdba
  set heading off
  set feedback off
  set trimout on
  SELECT 'SUCCESS' FROM dual;
EOF
}


# Loop through the databases given an verify we can connect as SYSDBA.
function precheckSysdba() {
  fname="${FUNCNAME[0]}"
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
      success=$(echo "${retcd}" | ${grep_cmd} SUCCESS)
      if [[ "${success}" =~ "SUCCESS" ]]; then
        echo " : SUCCESS"
        successes+=("SUCCESS : ${db}")
      else
        echo " : FAILED"
        echo "${retcd}"
        echo
        errors+=("FAILED : ${db}")
      fi
    fi
#  done < <( ${sed_cmd} "s/ //g;s/${tab_char}//g" "$configuration_file"  )
  done < <( tr -d ' ' < "${configuration_file}" | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' )

  pass_count=${#successes[@]}
  fail_count=${#errors[@]}

  echo
  echo "RESULTS:"
  if [[ ${pass_count} -gt 0 ]]; then
    echo
    echo "SUCCESSFUL SYSDBA CONNECTIONS:"
    printf '%s\n' "${successes[@]}"
  fi

  if [[ ${fail_count} -gt 0 ]]; then
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
  fname="${FUNCNAME[0]}"
  ${sqlplus_cmd} -s -L "${1}${2} " << EOF
  set heading off
  set feedback off
  set trimout on
  SELECT 'SUCCESS' FROM dual;
EOF
}


# Verify the DMA user is able to connect to the target databases.
function precheckUser() {
  fname="${FUNCNAME[0]}"
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
    success=$(echo "${retcd}" | ${grep_cmd} SUCCESS)
    if [[ "${success}" =~ "SUCCESS" ]]; then
      echo " : SUCCESS"
      successes+=("SUCCESS : ${db}" )
    else
      echo " : FAILED"
      echo "${retcd}"
      errors+=("${retcd} ${db}")
      echo
    fi

#  done < <( ${sed_cmd} "s/ //g;s/${tab_char}//g" "$configuration_file"  )
  done < <( tr -d ' ' < "${configuration_file}" | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' )

  echo
  echo
  echo "RESULTS:"
  echo "SUCCESSFUL CONNECTIONS:"
  printf '%s\n' "${successes[@]}"

  retcd=${#errors[@]}
  if [[ $retcd -gt 0 ]]; then
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
  if [[ "${verify_user}" = "Y" ]]; then
    if [[ $retval -eq 0 ]]; then precheckUser; retval=$?; fi
    if [[ $retval -eq 0 ]]; then precheckStats; retval=$?; fi
  fi
  if [[ $retval -eq 0 ]] && [[ $oee_entries -eq 1 ]] ; then precheck_oee_platform; retval=$?; fi

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


function print_usage() {
  echo
  echo " Usage:"
  echo "  Parameters"
  echo ""
  echo "  --configFile                Required.  Name of file containing a list of database connections and runtime options to verify."
  echo "                              File format is described in the header of the sample file in dma_db_list.csv. "
  echo
  echo "  --verifyUser                Optional.  Check only sysdba connectivity, skipping user connection check.  Use this to verify the"
  echo "                              sysdba user can connect before creating or modifing the collection user.  Default is Y."
  echo
  echo " Example:"
  echo      
  echo " Verify the sysdba user connection information is correct:"
  echo      
  echo "  ./dma_precheck.sh --connectionFile dma_db_list.csv --verifyUser N"
  echo      
  echo      
  echo " then, after running the dma_make_user.sh script, verify the user connection information as well:"
  echo
  echo "  ./dma_precheck.sh --connectionFile dma_db_list.csv"

}

### Validate input

function parse_parameters() {
  if [[ $# == 0 ]] ; then
    echo "Invalid number of parameters : $# $@"
    print_usage
    exit
  fi
  
  while (( "$#" )); do
    if   [[ "$1" == "--configFile" ]];           then configuration_file="${2}"
    elif [[ "$1" == "--verifyUser" ]];           then verify_user=$(echo "${2}" | tr '[:lower:]' '[:upper:]')
    else
      echo "Unknown parameter ${1}"
      print_usage
      exit 1
    fi
    shift 2
  done

  if [[ -z "${configuration_file}" ]]; then
    echo "Error : Must specify a connection configuration file to run the precheck."
    print_usage
    echo
    exit 1
  fi

  if [[ "${verify_user}" != "Y" ]] && [[ "${verify_user}" != "N" ]] ; then
    echo "Error : Parameter --verifyUser must be Y or N."
    print_usage
    echo
    exit 1
  fi  
}


function main() {
  parse_parameters "$@"

  if [[ -f "${configuration_file}" ]]; then 
    configfilelinecount=$(wc -l < <( tr -d ' ' < "${configuration_file}" | tr -d "${tab_char}" | grep -v '^#' | grep -v '^$' ))
    echo "Checking ${configfilelinecount} entries in file ${configuration_file}..."
    runAllChecks 
  else
    echo "File not found : ${configuration_file}"
  fi
}

main "$@" | tee ${dma_log_name}

