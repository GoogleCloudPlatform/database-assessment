spool &outputdir/opdb__dataguard__&v_tag

WITH vodg AS (
SELECT  '&&v_host'
        || '_'
        || '&&v_dbname'
        || '_'
        || '&&v_hora' AS pkey,
        &v_a_con_id as con_id, inst_id, dest_id, dest_name, destination, status, target, schedule, register,
        alternate, transmit_mode, affirm, valid_role, verify,
        CASE WHEN target = 'STANDBY' OR target = 'REMOTE' THEN (SELECT DECODE(listagg(value, ';') WITHIN GROUP (ORDER BY value), NULL, 'LOG_ARCHIVE_CONFIG_NOT_CONFIGURED', listagg(value, ';') WITHIN GROUP (ORDER BY value)) FROM gv$parameter WHERE UPPER(name) = 'LOG_ARCHIVE_CONFIG') ELSE 'LOCAL_DESTINATION_CONFIG_NOT_APPLICABLE' END log_archive_config
FROM gv$archive_dest a
WHERE destination IS NOT NULL)
SELECT pkey , con_id , inst_id , log_archive_config , dest_id , dest_name , destination , status ,
       target , schedule , register , alternate ,
       transmit_mode , affirm , valid_role , verify
FROM vodg;
spool off
