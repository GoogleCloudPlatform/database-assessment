spool &outputdir/opdb__usedspacedetails__&v_tag

WITH vused AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id,
       owner,
       segment_type,
       ROUND(SUM(bytes) / 1024 / 1024 / 1024, 0) GB
       FROM   &v_tblprefix._segments a
       WHERE  owner NOT IN (
                          SELECT name
                          FROM   SYSTEM.logstdby$skip_support
                          WHERE  action=0)
       GROUP  BY '&&v_host'
              || '_'
              || '&&v_dbname'
              || '_'
              || '&&v_hora',
              &v_a_con_id , owner, segment_type )
SELECT pkey , con_id , owner , segment_type , GB
FROM vused;
spool off
