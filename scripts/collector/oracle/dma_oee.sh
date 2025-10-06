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


