spool &outputdir/opdb__dbhwmarkstatistics__&v_tag

WITH vhwmst AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       description,
       highwater,
       last_value
FROM   dba_high_water_mark_statistics
ORDER  BY description)
SELECT pkey , description , highwater , last_value
FROM vhwmst;
spool off
