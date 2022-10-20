spool &outputdir/opdb__dblinks__&v_tag

WITH vdbl AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id,
       owner,
       count(1) count
FROM   &v_tblprefix._db_links a
WHERE username IS NOT NULL
/*
WHERE  owner NOT IN
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
*/
GROUP BY '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       &v_a_con_id , owner)
SELECT pkey , con_id , owner , count
FROM vdbl;
spool off
