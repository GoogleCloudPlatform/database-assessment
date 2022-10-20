spool &outputdir/opdb__opkeylog__&v_tag

with vop as (
select '&&v_tag' pkey, '&&version' opscriptversion, '&&v_dbversion' db_version, '&&v_host' hostname,
'&&v_dbname' db_name, '&&v_inst' instance_name, '&&v_hora' collection_time, &&v_dbid db_id, null "CMNT"
from dual)
select pkey , opscriptversion , db_version , hostname
       , db_name , instance_name , collection_time , db_id , CMNT
from vop;
spool off
