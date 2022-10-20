spool &outputdir/opdb__dbinstances__&v_tag

WITH vdbinst as (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       inst_id,
       instance_name,
       host_name,
       version,
       status,
       database_status,
       instance_role
FROM   gv$instance )
SELECT pkey , inst_id , instance_name , host_name ,
       version , status , database_status , instance_role
FROM vdbinst;
spool off
