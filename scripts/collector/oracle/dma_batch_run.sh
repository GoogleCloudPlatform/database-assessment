# Use this script to execute the dma collector in parallel via the list in dma_db_list.csv.
# The format of dma_db_list.csv is described in the header of that file.
# maxParallel controls how many DMA collectors can run at one time.
# We limit this in case there are multiple databases on the same host.
# Note that collection files can be large for databases with large number of objects,
# so ensure there is plenty of disk space available before increasing maxParallel.
# This script expects to run in bash shell, but should work in ksh.
. ./dma_print_pass_fail.sh
. ./dma_oee.sh

# Global vars
max_parallel=4
config_file=dma_db_list.csv
run_id=$(date +%Y%m%d%H%M%S)
tab_char=$(printf '\t')
this_pid=$$
script_dir=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
oee_dir=${script_dir}/oee
output_dir=${script_dir}/output; export output_dir
sql_dir=${script_dir}/sql
dma_log_name=DMA_BATCH_RUN_$(date +%Y%m%d%H%M%S).log

# Now handle platform-specific commands and variables.
# The default grep command in Solaris does not support the functionality required.  Need the alternative at /usr/xpg4/bin/awk.
if [[ "$(uname)" = "SunOS" ]]; then
  awk_cmd=/usr/xpg4/bin/awk
  sed_cmd=/usr/xpg4/bin/sed
  if [[ ! -f ${awk_cmd} ]]; then
    echo "Solaris requires compatible version of awk at ${awk_cmd}.  Please install awk and retry'."
    exit 1
  fi
  if [[ ! -f ${sed_cmd} ]]; then
    echo "Solaris requires compatible version of sed at ${sed_cmd}.  Please install sed and retry'."
    exit 1
  fi
else
  awk_cmd=$(which awk 2>/dev/null)
  sed_cmd=$(which sed 2>/dev/null)
fi

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
  fi
else
  grep_cmd=$(which grep 2>/dev/null)
fi

  
function count_children() {
  num_children=$(ps -ef | ${grep_cmd} "collect-data.sh" | ${grep_cmd} -v grep | wc -l)
  echo ${num_children}  
}


function batchRun() {
  local -i lineno=0
  local -i err_cnt=0
  local -i line_cnt=$(wc -l < <( tr -d ' ' < "${config_file}" | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' )) 
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
      oee_group="DEFAULT"
    fi
  
    # Run a collection in the background, capturing screen output to a log file.
    time ./collect-data.sh --connectionStr ''"${user}${db}"'' --statsSrc "${statssrc}" ${statsparam} --manualUniqueId "${dmaid}" --collectOEE "${oee_flag}" --oeeGroup "${oee_group}" --oee_runId "${run_id}" --dmaAutomation Y 2>&1 | tee "DMA_COLLECT_DATA_${batchlogname}_$(date +%Y%m%d%H%M%S)_${this_pid}.log" &

    # Wait a couple of seconds before starting another collection.
    sleep 2

    # Do not run another collection if there are too many running already
    echo "There are $(count_children) of ${max_parallel} processes running"
    while [[ $(count_children) -ge ${max_parallel} ]] ; do

      echo
      echo "Sleeping for 10 secs while waiting on child processes:"
      ps -ef | ${grep_cmd} "collect-data.sh" | ${grep_cmd} -v grep | cut -d '@' -f 2- | cut -d ' ' -f 1
      echo
      sleep 10
    done
  done < <( tr -d ' ' < "${config_file}" | tr -d "${tab_char}" | ${grep_cmd} -v '^#' | ${grep_cmd} -v '^$' )  

  echo "Waiting for remaining child processes to complete."
  wait
  echo "All child processes complete."

  echo "================================================================================================"
  echo "================================================================================================"
  #echo "Output files are in ${pwd}/${output_dir}"
  echo "Output files are in ${output_dir}"
  echo
  err_cnt=$(ls -1 ${output_dir}/*ERROR.zip 2>/dev/null | wc -l)
  # oee_errors=$(${grep_cmd} -h -A 5 "Skipping Estate Explorer collection" DMA_COLLECT_DATA_*_${this_pid}.log)
  oee_errors=$(grep -n "Skipping Estate Explorer collection" DMA_COLLECT_DATA_*_${this_pid}.log | cut -d: -f1 | xargs -n1 awk "NR>={}-0 && NR<={}+5" DMA_COLLECT_DATA_*_${this_pid}.log)

  if [[ ${err_cnt} -eq 0 ]] && [[ -z "${oee_errors}" ]] ; then
    #print_complete
    return 0
  fi

  if [[ ${err_cnt} -ne 0 ]]
  then
    echo "================================================================================================"
    echo "================================================================================================"
    print_fail
    echo "These collections encountered errors.  Check the log file for errors and re-try the collections after correcting the cause:"
    ls -1 ${output_dir}/*ERROR.zip
    echo
  fi

  if [[ ! -z "${oee_errors}" ]] ; then
    print_separator
    echo "Failed to collect Oracle Estate Explorer data :"
    echo "${oee_errors}"
    echo
    print_fail
  fi

  return 1
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


function main() {
  ### Validate input
  
  if [[ $(($# & 1)) == 1 ]] || [[ $# == 0 ]]  ;
  then
    echo "Invalid number of parameters $# : $@ "
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
        print_usage
        exit
      fi
    fi
    shift 2
  done
  
  if [[ -f "${config_file}" ]] ; then
    batchRun
    retval=$?
  
    if [[ ${retval} -eq 0 ]] ; then
      oee_file_count=$(wc -l < <(ls -1 "${oee_dir}"  | ${grep_cmd} "driverfile.${run_id}"))
      if [[ -d ${oee_dir} ]] && [[ ${oee_file_count} -gt 0 ]]; then
          echo "Running Oracle Estate Explorer for ${oee_file_count} groups."
          cd "${oee_dir}"
          oee_run "${run_id}" 2>&1 | tee "OEE_${dma_log_name}"
          echo "Checking log file OEE_${dma_log_name} for OEE failures}"

          for oee_fail_number in  $(${grep_cmd} "Database extract failures" "OEE_${dma_log_name}" | cut -d ':' -f 2 | tr -d ' '); do
            oee_fail_count=$(( ${oee_fail_count}  + ${oee_fail_number} ))
          done
          if [[ ${oee_fail_count} -ne 0 ]] ; then
            print_fail
          else
            print_complete
          fi
      else
        print_complete
      fi
    else
      print_separator
      echo "One or more collections encountered errors.  Please review the logs, remediate the errors and rerun the failed collection(s)."
    fi
  else
    echo "File not found : ${config_file}"
  fi
}

main "$@" 2>&1 | tee "${dma_log_name}"

