#!/usr/bin/env bash
set -eo pipefail 
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR=$(dirname ${SCRIPT_DIR})
sed "s/projectID.dataset/${PROJECTNAME}.${DSNAME}/g" $BASE_DIR/db_assessment//op_etl_template.sql > $SCRIPT_DIR/op_etl_${DSNAME}.sql
bq query  --use_legacy_sql=false < $SCRIPT_DIR/op_etl_${DSNAME}.sql  | tee op_etl_${DSNAME}.log
echo ""
echo "A log of this process is available at op_etl_${DSNAME}.log"
