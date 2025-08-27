# This script will parse the contents of the dma_db_list.csv file
# and verify the ability to connect as SYSDBA to each entry.
# This script expects to run in bash shell, but should execute in ksh also.
. ./dma_print_pass_fail.sh

CONFIGFILE=dma_db_list.csv

LOGNAME=dma_precheck_sysdba_$(date +%Y%m%d%H%M%S).log



function checkConnection
{
 sqlplus -s -L "${1}${2} as sysdba" << EOF
 set heading off
 set feedback off
 set trimout on
 SELECT 'SUCCESS' FROM dual;
EOF
}

function precheckSysdba
{
for x in $(cat "${CONFIGFILE}" | grep -v '^#' | grep -v '^$')
do
 sys=$(echo $x | cut -d ',' -f 1)
 db=$(echo $x | cut -d ',' -f 3)
 echo -n Testing SYSDBA connection to database ${db}
 retcd=$(sqlplus -s "${sys}${db} as sysdba" << EOF
 set heading off
 set feedback off
 set trimout on
 SELECT 'SUCCESS' FROM dual;
EOF)
retcd=$(checkConnection "${sys}" "${db}" )
success=$(echo "${retcd}" | grep SUCCESS)
if [ "${success}" = "SUCCESS" ]
then
  echo " : SUCCESS"
else
  echo " : FAILED"
  echo "${retcd}"
  echo
fi
done 2>&1 | tee $LOGNAME

PASS=$(grep SUCCESS $LOGNAME | wc -l)
FAIL=$(grep -v SUCCESS $LOGNAME | wc -l)
echo
echo
echo
echo ==========================================
echo ==========================================
echo ==========================================
echo ==========================================
echo ==========================================
echo RESULTS:
if [ ${PASS} -gt 0 ]
then
  echo SUCCESSFUL CONNECTIONS:
  grep SUCCESS $LOGNAME
fi

if [ ${FAIL} -gt 0 ]
then
  echo ==========================================
  echo
  print_fail
  echo FAILED CONNECTIONS:
  grep -v SUCCESS $LOGNAME
else
  print_pass
fi
}

### Validate input


 if [[ $(($# & 1)) == 1 ]] ;
 then
  echo "Invalid number of parameters "
  # printUsage
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

echo "Running precheckSysdba using configuration file ${CONFIGFILE}"

precheckSysdba

