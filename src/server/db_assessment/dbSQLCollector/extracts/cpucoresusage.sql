spool &outputdir/opdb__cpucoresusage__&v_tag

WITH vcpursc AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
       TO_CHAR(timestamp, 'MM/DD/YY HH24:MI') dt,
       cpu_count,
       cpu_core_count,
       cpu_socket_count
FROM   dba_cpu_usage_statistics
ORDER  BY timestamp)
SELECT pkey , dt , cpu_count , cpu_core_count , cpu_socket_count
FROM vcpursc;
spool off
