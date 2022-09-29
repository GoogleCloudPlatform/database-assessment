spool &outputdir/opdb__pdbsopenmode__&v_tag

WITH vpdbmode as (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                   AS pkey,
       con_id,
       name,
       open_mode,
       total_size / 1024 / 1024 / 1024 TOTAL_GB
FROM   v$pdbs )
SELECT pkey , con_id , name , open_mode , TOTAL_GB
FROM vpdbmode;
spool off
