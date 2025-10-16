# Use this script to execute the dma collector in parallel via the list in dma_db_list.csv.
# The format of dma_db_list.csv is described in the header of that file.
# maxParallel controls how many DMA collectors can run at one time.
# We limit this in case there are multiple databases on the same host.
# Note that collection files can be large for databases with large number of objects,
# so ensure there is plenty of disk space available before increasing maxParallel.
# This script expects to run in bash shell, but should work in ksh.
. ./dma_print_pass_fail.sh
. ./dma_oee.sh
max_parallel=4
config_file=dma_db_list.csv
run_id=$(date +%Y%m%d%H%M%S)
tab_char=$(printf '\t')
this_pid=$$
oee_dir=oee
output_dir=output


#TODO: This is for Solaris only
if [ "$(uname)" = "Solaris" ] ; then
  AWK=/usr/xpg4/bin/awk
else 
  AWK=$(which awk 2>/dev/null)
fi


function count_children() {
  num_children=$(ps -ef | grep "${this_pid}.log" | grep -v grep | wc -l)
  echo ${num_children}  
}


function batchRun() {
  local -i lineno=0
  local -i err_cnt=0
  local dma_log_name=DMA_BATCH_RUN_$(date +%Y%m%d%H%M%S).log
  local -i line_cnt=$(wc -l < <( tr -d ' ' < "${config_file}" | tr -d "${tab_char}" | grep -v '^#' | grep -v '^$' )) 
  echo "Found ${line_cnt} lines in config file"

  while IFS=, read -r sysUser user db statssrc statswindow dmaid oee_flag oee_group || [[ -n "$line" ]]; do
    lineno=$(( ${lineno} + 1 ))
    [[ ${lineno} -gt ${line_cnt} ]] && break   # Break out if the last line of the config file is a comment or empty

    echo "Processing configuration file ${config_file} line ${lineno} of ${line_cnt} for database ${db}"

    batchlogname=$(echo "${db}" | tr -d '\n' | tr  '[:punct:]' '[_*]')

    if [[ "${statssrc}" = "NONE" ]]
    then
      statsparam=""
    else
      statsparam="--statsWindow ${statswindow}"
    fi

    if [[ "${dmaid}" = "" ]] ; then
      dmaid="N/A"
    fi

    if [[ "${oee_flag}" = "" ]] ; then 
      oee_flag="N"
    else
      oee_flag=$(echo "${oee_flag}" | tr '[a-z]' '[A-Z]')
    fi

    if [[ "${oee_group}" = "" ]] ; then
      oee_group="NONE"
    fi
  
    # Run a collection in the background, capturing screen output to a log file.
    time ./collect-data.sh --connectionStr ''"${user}${db}"'' --statsSrc "${statssrc}" ${statsparam} --manualUniqueId "${dmaid}" --collectOEE "${oee_flag}" --oeeGroup "${oee_group}" --oeeRunId "${run_id}" --dmaAutomation Y 2>&1 | tee "DMA_COLLECT_DATA_${batchlogname}_$(date +%Y%m%d%H%M%S)_$$.log" &

    # Wait a couple of seconds before starting another collection.
    sleep 2

    # Do not run another collection if there are too many running already
    echo "There are $(count_children) of ${max_parallel} processes running"
    while [[ count_children -ge "${max_parallel}" ]] ; do
      echo "Sleeping for 10 secs while waiting on child processes."

      ps -ef | grep "${this_pid}.log" | grep -v grep

      sleep 10
    done
  done < <( tr -d ' ' < "${config_file}" | tr -d "${tab_char}" | grep -v '^#' | grep -v '^$' )  2>&1 | tee "${dma_log_name}"


  echo "================================================================================================"
  echo "================================================================================================"
  echo "Output files created:"
  ls -1 ${output_dir}/*.zip

  err_cnt=$(ls -1 ${output_dir}/*ERROR.zip 2>/dev/null | wc -l)
  if [ ${err_cnt} -ne 0 ]
  then
    echo "================================================================================================"
    echo "================================================================================================"
    print_fail
    echo "These collections encountered errors.  Check the log file for errors and re-try the collections after correcting the cause:"
    ls -1 ${output_dir}/*ERROR.zip
    echo
  else
    print_complete
  fi
  return ${err_cnt}
}


function run_oee() {
  oeeDedupDriverFiles "${run_id}" "{$oee_dir}"
  if [ $? -eq 0 ]; then oeePackageZips "${run_id}" "${oee_dir}"
  else print_fail
  fi

  if [ $? -eq 0 ]; then print_complete
  else print_fail
  fi
}


function print_usage() {
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

if [[ $(($# & 1)) == 1 ]] || [[ $# == 0 ]]  ;
then
  echo "Invalid number of parameters "
  print_usage
  exit
fi

while (( "$#" )); do
  if [[ "$1" == "--maxParallel" ]];
  then
    max_parallel="${2}"
  else
    if [[ "$1" == "--configFile" ]];
    then
      config_file="${2}"
    else
      echo "Unknown parameter ${1}"
      printUsage
      exit
    fi
  fi
  shift 2
done

if [[ -f "${config_file}" ]] ; then
  batchRun
  retval=$?

  oee_count=$(wc -l < <(ls -1 "${oee_dir}"  | grep "driverfile.${run_id}"))
  if [[ -d ${oee_dir} ]] && [[ "${oee_count}" -gt 0 ]]
  then
    echo "Running Oracle Estate Explorer for ${oee_count} groups."
    cd oee
    run_oee
    print_complete
  else
    print_complete
  fi
  if [[ "${retval}" -ne 0 ]]; then
    print_separator
    echo "One or more collections encountered errors.  Please review the logs, remediate the errors and rerun the failed collection(s)."
  fi
else
  echo "File not found : ${config_file}"
fi
