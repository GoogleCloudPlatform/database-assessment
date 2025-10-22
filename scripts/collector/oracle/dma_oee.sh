#
# Helper functions for Oracle Estate Explorer integration.  This script is not directly executable.
#

function oee_generate_config() {
  local oee_guid="${1}"
  local oee_database="${2}"
  local oee_hostName="${3}"
  local oee_port="${4}"
  local oee_user="${5}"
  local oee_pass="${6}"
  local oee_group="${7}" 
  local oee_runid="${8}"
  local v_file_tag="${9}"
    
  dbdomain=$(grep db_domain $output_dir/opdb__dbparameters__$v_file_tag | cut -d '|' -f 5 | uniq | head -1)
  if [ "${dbdomain}" != "" ]; then
    dbdomain=".${dbdomain}"
  fi
    
  # For single tenant or container databases
  oee_guid=$(echo ${oee_guid} | ${md5_cmd} | cut -d ' ' -f ${md5_col})
  echo ${oee_guid}:${oee_database}://${oee_hostName}:${oee_port}/${oee_database}:${oee_user}:${oee_pass} >> ${oee_dir}/mpack_DMA${oee_group}.driverfile.${oee_runid}
    
  # For multitenant, we need to add entries for all the pluggable databases.
  if [ -f $output_dir/opdb__pdb_summary__$v_file_tag ] ; then
    for pdbname in $(${grep_cmd} -v -e PKEY -e "CDB\$ROOT" -e "PDB\$SEED" $output_dir/opdb__pdb_summary__$v_file_tag | ${grep_cmd} -e "READ WRITE" -e "READ ONLY" -e "^----" | cut -d '|' -f 4)
    do
      echo Adding pluggable database ${pdbname} to driverfile ${oee_runid}
      oee_guid=$(echo ${oee_guid}${pdbname}${dbdomain} | ${md5_cmd} | cut -d ' ' -f ${md5_col})
      echo ${oee_guid}:${pdbname}://${oee_hostName}:${oee_port}/${pdbname}${dbdomain}:${oee_user}:${oee_pass} >> ${oee_dir}/mpack_DMA${oee_group}.driverfile.${oee_runid}
    done
  elif [ -f $output_dir/opdb__pdbsopenmode__$v_file_tag ] ; then
    for pdbname in $(${grep_cmd} -v -e PKEY -e "CDB\$ROOT" -e "PDB\$SEED" $output_dir/opdb__pdbsopenmode__$v_file_tag | ${grep_cmd} -e "READ WRITE" -e "READ ONLY" -e "^----" | cut -d '|' -f 3)
    do
      echo Adding pluggable database ${pdbname} to driverfile ${oee_runid}
      oee_guid=$(echo ${oee_guid}${pdbname} | ${md5_cmd} | cut -d ' ' -f ${md5_col})
      echo ${oee_guid}:${pdbname}://${oee_hostName}:${oee_port}/${pdbname}${dbdomain}:${oee_user}:${oee_pass} >> ${oee_dir}/mpack_DMA${oee_group}.driverfile.${oee_runid}
    done
  fi  
}   


function oee_run_standalone_extract() {
  local oee_runid="${1}"
  echo Looking for driver files in $(pwd)

  for fname in $(ls -1 *driverfile.${oee_runid})
  do
    echo Processing file ${fname}
    newName=$(echo ${fname} |  ${AWK} -F '.'  '{OFS="."; for (i = 1; i <= NF - 1; i++) { printf "%s%s", $i, (i < (NF - 1) ? OFS : "\n")}  }')
    sort -u ${fname} > ${newName}
    ./oee_group_extract-SA.sh ${newName} <<EOF
2
EOF
  done
}


function oee_package_zips() {
  local oee_runid="${1}"
  for zipname in $(ls -1 *driverfile.${oee_runid} | cut -d '_' -f 2- | cut -d '.' -f 1 )
  do
    if [ -f ${zipname}.zip ] ; then
      echo Moving OEE file ${zipname}.zip to DMA output directory.
      mv ${zipname}.zip ../${output_dir}/${zipname}.zip
    else
      echo Error: Could not locate output file ${zipfile}.zip !!
    fi
  done
}


function oee_run() {
  local oee_runid="${1}"

  oee_run_standalone_extract "${oee_runid}"

  if [ $? -eq 0 ]; then 
    oee_package_zips "${oee_runid}"
  else 
    return 1
  fi

  if [ $? -eq 0 ]; then 
    return 0
  else 
    return 1
  fi
}


# OEE Requires SQL*Plus version 12.1 or higher
function oee_check_sqlplus_release {
  local retval="FAIL"
  sql_client=$(sqlplus -s /nolog <<EOF
  prompt &_SQLPLUS_RELEASE
  exit;
EOF
  )
  if [[ "${sql_client}" == *"SP2-"* ]]; then
    retval="FAIL: ${sql_client}"
  else
    sqlclientver=$(echo "${sql_client}" | cut -c 1-2)
    if [[ "${sqlclientver}" -ge 12 ]] 
    then 
      retval="PASS"
    else
      retval="FAIL: ${sql_client}"  
    fi
  fi
  echo "${retval}"
}


# OEE Requires database 10g or higher
function oee_check_db_version {
  connectString="$1"
  RETVAL="FAIL"

  dbVer=$(
sqlplus -s /nolog << EOF
SET DEFINE OFF
connect ${connectString}
@${sql_dir}/dma_set_sql_env.sql
set pagesize 0 lines 400 feedback off verify off heading off echo off timing off time off
WITH mj AS (
SELECT substr(version, 1, INSTR(version, '.', 1, 2)-1) AS version
FROM v\$instance)
SELECT 'CONNECTED|' || 
       SUBSTR(version, 1, INSTR(version, '.')-1) || '|' || -- Major 
       SUBSTR(version, INSTR(version, '.')+1)              -- Minor
FROM mj;
exit;
EOF
)
  if [[ "${dbVer}" == "CONNECTED"* ]] ; then
    dbMajor=$(echo "${dbVer}" | cut -d '|' -f 2)
    dbMinor=$(echo "${dbVer}" | cut -d '|' -f 3)

    if [[ ${dbMajor} -gt 10 ]] ; then
        RETVAL="PASS"
    else 
      if [[ ${dbMajor} -eq 10 ]] ; then
        if [[ ${dbMinor} -ge 2 ]] ; then
          RETVAL="PASS"
        fi
      fi
    fi
  else 
    RETVAL="FAIL: ${dbVer}"
  fi
  echo ${RETVAL}
}


# Check the platform on which the script is running.
# Fail on all platforms other than officially supported.
function oee_check_platform() {
  local PLT=$(uname)
  local ret_val="FAIL"
  case "${PLT}" in
    "Linux" ) 
      ret_val="PASS"
      ;;
    "Darwin" ) 
      ret_val="PASS"
      ;;
    * )
      ret_val="FAIL due to unsupported platform ${PLT}"
  esac
  echo "${ret_val}"
}

# Check that all conditions are correct for running OEE
function oee_check_conditions {
  local connectString="${1}"
  local connectDest=$(echo "${connectString}" | cut -d '@' -f 2)
  local RETVAL="FAIL"
  local DBV="N/A"

  if [[ -f $oee_dir/oee_group_extract-SA.sh ]] ; then
      
    PLT="$(oee_check_platform)"
    SPR=$(oee_check_sqlplus_release)
    DBV="$(oee_check_db_version ${connectString})"
    
    if [[ "${SPR}" == "PASS" ]] && [[ "${DBV}" == "PASS" ]] && [[ "${PLT}" == "PASS" ]]; then
      RETVAL="PASS"
    fi  
  fi

  if [[ "${RETVAL}" != "PASS" ]] ; then 
    echo "Failure testing connection ${connectDest}" 
    echo "SQLPlus Release   ${SPR}"
    echo "Database Version  ${DBV}"
    echo "Platform          ${PLT}"
  else
    echo "${RETVAL}"
  fi
}

