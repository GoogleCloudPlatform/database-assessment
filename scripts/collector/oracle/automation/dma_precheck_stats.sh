# This script will parse the contents of the dma_db_list.csv file
# and verify the ability to connect as SYSDBA to each entry.
# This script expects to run in bash shell, but should execute in ksh also.
. ./dma_print_pass_fail.sh
LOGNAME=dma_precheck_stats_$(date +%Y%m%d%H%M%S).log
CONFIGFILE=dma_db_list.csv
MINDAYS=7

function checkStats
{
 sqlplus -S  -L "${1}${2} " << EOF
 set heading off
 set feedback off
 set trimout on
 set lines 132
 set serveroutput on size 5000
DECLARE retval VARCHAR2(1000);
        statsSrc VARCHAR2(10) := '${3}';
        cnt NUMBER := 0;
        numdays NUMBER;
        snapsperday NUMBER;
        sqlStr VARCHAR2(1000);
BEGIN
  IF statsSrc = 'AWR' THEN
   BEGIN
    SELECT count(1) INTO cnt FROM all_views WHERE view_name LIKE '%_HIST_SNAPSHOT';
    IF nvl(cnt,0) < 1 THEN 
       retval := 'FAILED : User has no permissions to select from the AWR tables.  Please execute the grants_wrapper.sql script for this user.';
    ELSE
      sqlStr := 'SELECT  EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) ) FROM dba_hist_snapshot WHERE begin_interval_time < trunc(sysdate)';
      EXECUTE IMMEDIATE sqlStr INTO numdays;
      IF numdays > 0 THEN
        sqlStr := REPLACE('SELECT ~SUCCESS AWR        START ~ || to_char( min(begin_interval_time), ~YYYY-MM-DD HH24:MI~) || ~  END ~ || to_char(max(begin_interval_time), ~YYYY-MM-DD HH24:MI~) || ~  #SNAPS ~ || LPAD(count(1),4) || ~  #DAYS ~, EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) )
      , (count(1) / EXTRACT (DAY FROM max(begin_interval_time) - min(begin_interval_time) ) )
        FROM dba_hist_snapshot
        WHERE begin_interval_time <= trunc(sysdate)', '~', chr(39));
        EXECUTE IMMEDIATE sqlStr INTO retval, numdays, snapsperday;
        retval := retval || LPAD(numdays, 4) || '  SnapsPerDay ' || round(snapsperday) ;
      END IF;
      IF numdays < ${MINDAYS} THEN
         retval := 'FAILED : Not enough days of AWR snapshots.  Need at least 7 full calendar days of snapshots, but only ' || numdays || ' day(s) found.';
      ELSE IF round(snapsperday) < 23 THEN
         retval := 'FAILED : AWR snapshot interval appears to be more than 1 hour between snapshots. Found an average of ' || round(snapsperday,2) || ' snapshots per day and expecting ~ 24.';
      END IF;
      END IF;
    END IF;
   END;
  ELSIF statsSrc = 'STATSPACK' THEN
        SELECT count(1) INTO cnt 
        FROM all_tables 
        WHERE owner ='PERFSTAT' 
          AND table_name IN ('STATS\$OSSTAT', 'STATS\$OSSTATNAME', 'STATS\$SNAPSHOT', 'STATS\$SQL_SUMMARY', 'STATS\$SYSSTAT', 'STATS\$SYSTEM_EVENT', 'STATS\$SYS_TIME_MODEL', 'STATS\$TIME_MODEL_STATNAME');

         -- If we have access to STATSPACK, use STATSPACK as the source of performance metrics
 	 IF cnt = 8 THEN
            sqlStr := 'SELECT (max(snap_time) -min(snap_time)) FROM PERFSTAT.STATS\$SNAPSHOT WHERE snap_time <= (sysdate) AND snap_time >= trunc(sysdate - ${MINDAYS})';
            EXECUTE IMMEDIATE sqlStr INTO numdays;
            IF numdays > 0 THEN 
              sqlStr := REPLACE('SELECT ~SUCCESS STATSPACK  START ~ || to_char(min(snap_time), ~YYYY-MM-DD HH24:MI~) || ~  END ~ || to_char(max(snap_time), ~YYYY-MM-DD HH24:MI~) || ~  #SNAPS ~ || LPAD(count(1), 4) || ~  #DAYS ~ , to_char(trunc(max(snap_time) -min(snap_time) )) , count(1) / (max(snap_time) -min(snap_time) )
              FROM PERFSTAT.STATS\$SNAPSHOT
              WHERE snap_time <= (sysdate)
              AND snap_time >= trunc(sysdate - ${MINDAYS})', '~', chr(39));
              EXECUTE IMMEDIATE sqlStr INTO retval, numdays, snapsperday;
              retval := retval || LPAD(numdays,4) || '  SnapsPerDay ' || ROUND(snapsperday);
            END IF;
         ELSE
            retval := 'FAILED due to missing some STATSPACK tables. Expecting 8 tables but found ' || cnt;
         END IF;
         IF numdays < ${MINDAYS} THEN
            retval := 'FAILED : Not enough days of STATPACK snapshots.  Need at least ${MINDAYS} full calendar days of snapshots, but only ' || numdays || ' day(s) found.';
         ELSE IF ROUND(snapsperday) < 23 THEN
                retval := 'FAILED : STATSPACK snapshot interval appears to be more than 1 hour between snapshots. Found an average of ' || round(snapsperday,2) ||' snapshots per day and expecting ~ 24.';
              END IF;
         END IF;
  ELSIF statsSrc = 'NONE' or statsSrc = 'NOSTATS' THEN
    retval := 'NONE : NO PERFORMANCE STATISTICS WILL BE COLLECTED';
  ELSE
    retval := 'ERROR : Unrecognized value ' || statsSrc || ' in configuration file.';
  END IF;
  dbms_output.put_line(retval);  
END;
/
EOF
}

function precheckStats
{
for x in $(cat "${CONFIGFILE}" | grep -v '^#' | grep -v '^$')
do
 user=$(echo "${x}" | cut -d ',' -f 2 | tr -d "'")
 username=$(echo "${user}" | cut -d '/' -f 1)
 db=$(echo $x | cut -d ',' -f 3)
 statssrc=$(echo $x | cut -d ',' -f 4)
 echo
 echo -n Checking available performance statstics on database ${db} user "${username}" for ${statssrc}
 retcd=$(checkStats "${user}" "${db}" "${statssrc}")
 success=$(echo "${retcd}" | grep -e SUCCESS -e NONE | cut -d ' ' -f 1)
 if [ "${success}" = "SUCCESS" ]
 then
  echo " : ${retcd}"
 else if [ "${success}" = "NONE" ]
      then
        echo " : ${retcd}"
      else
        echo " : FAILED"
        echo "${retcd}"
        echo
      fi
fi
done 2>&1  | tee  $LOGNAME

echo
echo
echo
echo
echo ==========================================
echo ==========================================
echo ==========================================
echo ==========================================
echo ==========================================
echo
print_summary
retcd=$(grep SUCCESS $LOGNAME | wc -l)
if [ $retcd -gt 0 ]
then
  echo SUCCESS:  These databases have at least ${MINDAYS} calendar days of performance statistics available:
  grep SUCCESS $LOGNAME
fi

retcd=$(grep NONE $LOGNAME | wc -l)
if [ $retcd -gt 0 ]
then
  echo
  echo These databases will not have performance stats collected as the parameter NONE or NOSTATS was given in the configuration file. 
  grep NONE $LOGNAME
fi

retcd=$(grep -v SUCCESS $LOGNAME | grep -v -e NONE -e Checking | wc -l)
if [ $retcd -gt 0 ]
then
  echo
  echo Overall status
  print_fail
  echo ==========================================
  echo
  echo FAILED:  These databases did not pass for the below reasons :
  grep -B 2 -v -e SUCCESS -e Checking -e "^$" $LOGNAME | grep -v NONE
  echo 
else
  echo
  echo Overall status
  print_pass

fi
}

### Validate input


 if [[ $(($# & 1)) == 1 ]] ;
 then
  echo "Invalid number of parameters "
  #printUsage
  exit
 fi

 while (( "$#" )); do
	 if   [[ "$1" == "--configFile" ]];            then CONFIGFILE="${2}"
	 else
		 echo "Unknown parameter ${1}"
		 #printUsage
		 exit
         fi
	 shift 2
 done

echo "Running precheckStats using configuration file ${CONFIGFILE}"

precheckStats 

