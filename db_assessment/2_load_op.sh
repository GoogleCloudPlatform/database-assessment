THISD=$(pwd)
bq mk -d --data_location=${DSLOC} ${DSNAME}
cd ${OP_WORKING_DIR}/..
for COLID in $(ls -1 ${OP_LOG_DIR}/opdb*| rev | cut -d '.' -f 2 | rev | sort | uniq)
do
python3 ./db_assessment/optimusprime.py -sep "${COLSEP}" -dataset ${DSNAME} -fileslocation ${OP_LOG_DIR} -projectname ${PROJECTNAME} -collectionid ${COLID} | tee ${THISD}/opload-${DSNAME}-${COLID}.log
done
echo
echo Logs of this upload are available at:
echo
ls -l ${THISD}/opload-${DSNAME}-*.log
echo
cd ${THISD}
