set termout on
column min_snapid new_value v_min_snapid noprint
column max_snapid new_value v_max_snapid noprint

SELECT MIN(snap_id) min_snapid,
       MAX(snap_id) max_snapid
FROM   STATS$SNAPSHOT
WHERE  SNAP_TIME > ( SYSDATE - '&&dtrange' )
AND dbid = '&&v_dbid'
/

prompt Collecting STATSPACK data for database &v_dbname '&&v_dbid' between snaps &v_min_snapid and &v_max_snapid

set termout &TERMOUTOFF

