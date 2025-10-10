#
# Helper functions for Oracle Estate Explorer integration
#

function oeeGenerateConfig() {
  oee_guid="${1}"
  oee_database="${2}"
  oee_hostName="${3}"
  oee_port="${4}"
  oee_user="${5}"
  oee_pass="${6}"
  oee_group="${7}" 
  oee_runid="${8}"
  V_FILE_TAG="${9}"
    
  dbdomain=$(grep db_domain $OUTPUT_DIR/opdb__dbparameters__$V_FILE_TAG | cut -d '|' -f 5 | uniq | head -1)
  if [ "${dbdomain}" != "" ]; then
    dbdomain=".${dbdomain}"
  fi
    
  # For single tenant or container databases
  oee_guid=$(echo ${oee_guid} | md5sum | cut -d ' ' -f ${MD5COL})
  echo ${oee_guid}:${oee_database}://${oee_hostName}:${oee_port}/${oee_database}:${oee_user}:${oee_pass} >> ${OEE_DIR}/mpack_DMA${oee_group}.driverfile.${oee_runid}
    
  # For multitenant, we need to add entries for all the pluggable databases.
  if [ -f $OUTPUT_DIR/opdb__pdb_summary__$V_FILE_TAG ] ; then
    for pdbname in $($GREP -v -e PKEY -e "CDB\$ROOT" -e "PDB\$SEED" $OUTPUT_DIR/opdb__pdb_summary__$V_FILE_TAG | $GREP -e "READ WRITE" -e "READ ONLY" -e "^----" | cut -d '|' -f 4)
    do
      echo Adding pluggable database ${pdbname} to driverfile ${oee_runid}
      oee_guid=$(echo ${oee_guid}${pdbname}${dbdomain} | md5sum | cut -d ' ' -f ${MD%COL})
      echo ${oee_guid}:${pdbname}://${oee_hostName}:${oee_port}/${pdbname}${dbdomain}:${oee_user}:${oee_pass} >> ${OEE_DIR}/mpack_DMA${oee_group}.driverfile.${oee_runid}
    done
  elif [ -f $OUTPUT_DIR/opdb__pdbsopenmode__$V_FILE_TAG ] ; then
    for pdbname in $($GREP -v -e PKEY -e "CDB\$ROOT" -e "PDB\$SEED" $OUTPUT_DIR/opdb__pdbsopenmode__$V_FILE_TAG | $GREP -e "READ WRITE" -e "READ ONLY" -e "^----" | cut -d '|' -f 3)
    do
      echo Adding pluggable database ${pdbname} to driverfile ${oee_runid}
      oee_guid=$(echo ${oee_guid}${pdbname} | md5sum | cut -d ' ' -f ${MD5COL})
      echo ${oee_guid}:${pdbname}://${oee_hostName}:${oee_port}/${pdbname}${dbdomain}:${oee_user}:${oee_pass} >> ${OEE_DIR}/mpack_DMA${oee_group}.driverfile.${oee_runid}
    done
  fi  
}   


function oeeDedupDriverFiles() {
  RUNID="${1}"
  cd oee
  echo "RunID = ${RUNID}"
  for fname in $(ls -1 *driverfile.${RUNID})
  do
    echo Processing file ${fname}
    newName=$(echo ${fname} | rev |  cut -d '.' -f 2- | rev)
    sort -u ${fname} > ${newName}
    ./oee_group_extract-SA.sh ${newName} <<EOF
2
EOF
  done
}

function oeePackageZips() {
  RUNID="${1}"
  for zipname in $(ls -1 *driverfile.${RUNID} | cut -d '_' -f 2- | cut -d '.' -f 1 )
  do
    if [ -f ${zipname}.zip ] ; then
      echo Moving OEE file ${zipname}.zip to DMA output directory.
      mv ${zipname}.zip ../output/${zipname}.zip
    else
      echo Error: Could not locate output file ${zipfile}.zip !!
    fi
  done
}

function oeeRun() {
  RUNID="${1}"
  echo RUNID = "${RUNID}"
  oeeDedupDriverFiles "${RUNID}"
  if [ $? -eq 0 ]; then oeePackageZips "${RUNID}"
  else print_fail
  fi

  if [ $? -eq 0 ]; then print_complete
  else print_fail
  fi
}


# OEE Requires SQL*Plus version 12.1 or higher
function oeeCheckSQLPlusRelease {
  RETVAL="FAIL"
  SQLCLIENT=$(sqlplus -s /nolog <<EOF
  prompt &_SQLPLUS_RELEASE
  exit;
EOF
  )
  if [[ "${SQLCLIENT}" == *"SP2-"* ]]; then
    RETVAL="FAIL: ${SQLCLIENT}"
  else
    SQLCLIENTVER=$(echo "${SQLCLIENT}" | cut -c 1-2)
    if [[ "${SQLCLIENTVER}" -ge 12 ]] 
    then 
      RETVAL="PASS"
    else
      RETVAL="FAIL: ${SQLCLIENT}"  
    fi
  fi
  echo "${RETVAL}"
}


# OEE Requires database 10g or higher
function oeeCheckDbVersion {
  connectString="$1"
  RETVAL="FAIL"

  dbVer=$(
${SQLPLUS} -s /nolog << EOF
SET DEFINE OFF
connect ${connectString}
@${SQL_DIR}/op_set_sql_env.sql
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


# Check that all conditions are correct for running OEE
function oeeCheckConditions {
  connectString="${1}"
  connectDest=$(echo "${connectString}" | cut -d '@' -f 2)
  RETVAL="FAIL"
  DBV="N/A"

  if [[ -f $OEE_DIR/oee_group_extract-SA.sh ]] ; then
      
    SPR=$(oeeCheckSQLPlusRelease)
    
    if [[ "${SPR}" == "PASS" ]] ; then
      DBV=$(oeeCheckDbVersion ${connectString})
      if [[ "${DBV}" == "PASS" ]]; then
          RETVAL="PASS"
      fi
    fi  
  fi
  if [[ "${RETVAL}" != "PASS" ]] ; then 
    echo "Failure testing connection ${connectDest}" 
    echo "SQLPlus Release   ${SPR}"
    echo "Database Version  ${DBV}"
  else
    echo "${RETVAL}"
  fi
}

