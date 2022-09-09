sed "s/projectID.dataset/${PROJECTNAME}.${DSNAME}/g" op_etl_template.sql > op_etl_${DSNAME}.sql
bq query  --use_legacy_sql=false <op_etl_${DSNAME}.sql  | tee op_etl_${DSNAME}.log
echo
echo A log of this process is available at op_etl_${DSNAME}.log