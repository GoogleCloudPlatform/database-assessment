spool &outputdir/opdb__indexestypes__&v_tag

WITH vidxtype AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id,
       owner,
       index_type,
       COUNT(1) as cnt
FROM   &v_tblprefix._indexes a
WHERE  owner NOT IN
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          &v_a_con_id ,
          owner,
          index_type)
SELECT pkey , con_id , owner , index_type , cnt
FROM vidxtype;
spool off
