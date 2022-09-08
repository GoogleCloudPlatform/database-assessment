spool &outputdir/opdb__datatypes__&v_tag

WITH vdtype AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id con_id,
       owner,
       data_type,
       COUNT(1) as cnt
FROM   &v_tblprefix._tab_columns a
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
          data_type)
SELECT pkey , con_id , owner , data_type , cnt
FROM vdtype;
spool off
