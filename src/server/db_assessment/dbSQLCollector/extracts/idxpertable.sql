spool &outputdir/opdb__idxpertable__&v_tag

WITH vrawidx AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id, table_owner, table_name, count(1) idx_cnt
FROM &v_tblprefix._indexes a
WHERE  owner NOT IN
                    ( SELECT name
                      FROM   SYSTEM.logstdby$skip_support
                      WHERE  action=0)
group by &v_a_con_id, table_owner, table_name),
vcidx AS (
SELECT pkey,
       con_id,
       count(table_name) tab_count,
       idx_cnt,
       round(100*ratio_to_report(count(table_name)) over ()) idx_perc
FROM vrawidx
GROUP BY pkey, con_id, idx_cnt)
SELECT pkey , con_id , tab_count , idx_cnt , idx_perc
FROM vcidx;
spool off
