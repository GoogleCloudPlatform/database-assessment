# This script will parse the contents of the dma_db_list.csv file
# and verify the ability to connect as SYSDBA to each entry.
# This script expects to run in bash shell, but should execute in ksh also.
. ./dma_print_pass_fail.sh
LOGNAME=dma_precheck_user_$(date +%Y%m%d%H%M%S).log
CONFIGFILE=dma_db_list.csv

function checkConnection
{
 sqlplus -s -L "${1}${2} " << EOF
 set heading off
 set feedback off
 set trimout on
 SELECT 'SUCCESS' FROM dual;
EOF
}

function precheckUser
{
for x in $(cat "${CONFIGFILE}" | grep -v '^#' | grep -v '^$')
do
 user=$(echo $x | cut -d ',' -f 2)
 db=$(echo $x | cut -d ',' -f 3)
 echo -n Testing DMA user connection to database ${db}
 retcd=$(checkConnection "${user}" "${db}" )
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
echo RESULTS:
echo SUCCESSFUL CONNECTIONS:
grep SUCCESS $LOGNAME

retcd=$(grep -v SUCCESS $LOGNAME | wc -l)
if [ $retcd -gt 0 ]
then
  echo 
  echo Overall result:
  print_fail
  echo
  echo
  echo ==========================================
  echo
  echo FAILED CONNECTIONS:
  grep -v SUCCESS $LOGNAME
  print_fail
  else
    echo
    echo Overall result:
    echo
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

precheckUser
