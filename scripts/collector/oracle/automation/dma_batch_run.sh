# Use this script to execute the dma collector in parallel via the list in dma_db_list.csv.
# The format of dma_db_list.csv is described in the header of that file.
# maxParallel controls how many DMA collectors can run at one time.  
# We limit this in case there are multiple databases on the same host.
# Note that collection files can be large for databases with large number of objects,
# so ensure there is plenty of disk space available before increasing maxParallel.
# This script expects to run in bash shell, but should work in ksh.
. ./dma_print_pass_fail.sh
MAXPARALLEL=5
CONFIGFILE=dma_db_list.csv

function batchRun {
CURRD=$(pwd)
LOGNAME=DMA_BATCH_RUN_$(date +%Y%m%d%H%M%S).log
for x in $(cat "${CONFIGFILE}" | grep -v '^#' | grep -v '^$' |grep '@')
do
 user=$(echo $x | cut -d ',' -f 2)
 db=$(echo $x | cut -d ',' -f 3)
 statssrc=$(echo $x | cut -d ',' -f 4)
 statswindow=$(echo $x | cut -d ',' -f 5)
 logname=$(echo $db | tr  -c 'a-zA-Z0-9' '_')
 if [ "${statssrc}" = "NONE" ] 
 then
   statsparam=""
 else
   statsparam="--statsWindow ${statswindow}"
 fi
 cd ${CURRD}/..
 # Run a collection in the background, capturing screen output to a log file.
 time  ./collect-data.sh --dbType oracle --connectionStr ''${user}${db}'' --statsSrc ${statssrc} ${statsparam} 2>&1 | tee DMA_COLLECT_DATA_${logname}_$(date +%Y%m%d%H%M%S)_$$.log &

# Wait a couple of seconds before starting another collection.
 sleep 2
 
 # Do not run another collection if there are too many running already
 while [[ $(ps -ef | grep collect-data | grep -v grep | wc -l) -ge ${MAXPARALLEL} ]]
 do
  echo sleeping for 10 secs while waiting on collections:
  ps | grep collect-data.sh | grep -v grep 
  #ps | grep collect-data.sh | grep -v grep | cut -d '@' -f 2 | cut -d ' ' -f 1

  sleep 10
 done
done 2>&1 | tee ${LOGNAME}

echo ================================================================================================
echo ================================================================================================
echo Output files created:
ls -1 ${CURRD}/../output/*.zip

ERRCNT=$(ls -1 ${CURRD}/../output/*ERROR.zip 2>/dev/null | wc -l)
if [ ${ERRCNT} -ne 0 ]
then
  echo ================================================================================================
  echo ================================================================================================
  print_fail
  echo These collections encountered errors.  Check the log file for errors and re-try the collections after correcting the cause:
  ls -1 ${CURRD}/../output/*ERROR.zip
  echo
else
  print_complete
fi
}

function printUsage {
echo " Usage:"
echo "    This script will read a configuration file (dma_db_list.csv) and execute a DMA collection process against each database "
echo "    listed in the file, running several collections in parallel.  The number of simultaeous collections can be controlled "
echo "    via the maxParallel parameter.  This controls the number of DMA collections running at one time, not the parallelism "
echo "    within the database.  Each collection process will consume disk space on the machine running this script, so do not just "
echo "    set maxParallel to the number of databases to process. " 
echo "  Parameters"
echo ""
echo "  Maximum number of collections to allow at one time."
echo "      --maxParallel      Optional.  Controls the number of collection process that may run simultaneously in the background.  Default value is 5."
echo "      --configFile       Optional.  Name of the csv file listing the databases to assess.  Default value is dma_db_list.csv."
echo ""
}

### Validate input


 if [[ $(($# & 1)) == 1 ]] ;
 then
  echo "Invalid number of parameters "
  printUsage
  exit
 fi

 while (( "$#" )); do
	 if   [[ "$1" == "--maxParallel" ]];           then MAXPARALLEL="${2}"
	 else if   [[ "$1" == "--configFile" ]];            then CONFIGFILE="${2}"
	 else
		 echo "Unknown parameter ${1}"
		 printUsage
		 exit
	 fi
         fi
	 shift 2
 done

batchRun 

