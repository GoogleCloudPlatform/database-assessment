spool &outputdir/opdb__compressbytype__&v_tag

WITH vcompresstype AS (
     SELECT '&&v_host'
            || '_'
            || '&&v_dbname'
            || '_'
            || '&&v_hora' AS pkey,
	        con_id,
            owner,
            TRUNC(SUM(DECODE(compress_for, 'BASIC', gbytes,
                                           0))) basic,
            TRUNC(SUM(DECODE(compress_for, 'OLTP', gbytes,
                                           'ADVANCED', gbytes,
                                           0))) oltp,
            TRUNC(SUM(DECODE(compress_for, 'QUERY LOW', gbytes,
                                           0))) query_low,
            TRUNC(SUM(DECODE(compress_for, 'QUERY HIGH', gbytes,
                                           0))) query_high,
            TRUNC(SUM(DECODE(compress_for, 'ARCHIVE LOW', gbytes,
                                           0))) archive_low,
            TRUNC(SUM(DECODE(compress_for, 'ARCHIVE HIGH', gbytes,
                                           0))) archive_high,
            TRUNC(SUM(gbytes))                  total_gb
     FROM   (SELECT &v_a_con_id AS con_id,
                    a.owner,
                    a.compress_for,
                    SUM(bytes / 1024 / 1024 / 1024) gbytes
             FROM   &v_tblprefix._tables a,
                    &v_tblprefix._segments b
             WHERE  &v_a_con_id = &v_b_con_id
                    AND a.owner = b.owner
                    AND a.table_name = b.segment_name
                    AND b.partition_name IS NULL
                    AND compression = 'ENABLED'
                    AND a.owner NOT IN
                                       (
                                       SELECT name
                                       FROM   SYSTEM.logstdby$skip_support
                                       WHERE  action=0)
             GROUP  BY &v_a_con_id,
                       a.owner,
                       a.compress_for
             UNION ALL
             SELECT &v_a_con_id,
                    a.table_owner,
                    a.compress_for,
                    SUM(bytes / 1024 / 1024 / 1024) gbytes
             FROM   &v_tblprefix._tab_partitions a,
                    &v_tblprefix._segments b
             WHERE  &v_a_con_id = &v_b_con_id
                    AND a.table_owner = b.owner
                    AND a.table_name = b.segment_name
                    AND a.partition_name = b.partition_name
                    AND compression = 'ENABLED'
                    AND a.table_owner NOT IN
                                              (
                                              SELECT name
                                              FROM   SYSTEM.logstdby$skip_support
                                              WHERE  action=0)
             GROUP  BY &v_a_con_id,
                       a.table_owner,
                       a.compress_for
             UNION ALL
             SELECT &v_a_con_id,
                    a.table_owner,
                    a.compress_for,
                    SUM(bytes / 1024 / 1024 / 1024) gbytes
             FROM   &v_tblprefix._tab_subpartitions a,
                    &v_tblprefix._segments b
             WHERE  &v_a_con_id = &v_b_con_id
                    AND a.table_owner = b.owner
                    AND a.table_name = b.segment_name
                    AND a.subpartition_name = b.partition_name
                    AND compression = 'ENABLED'
                    AND a.table_owner NOT IN
                                              (
                                              SELECT name
                                              FROM   SYSTEM.logstdby$skip_support
                                              WHERE  action=0)
             GROUP  BY &v_a_con_id,
                       a.table_owner,
                       a.compress_for)
     GROUP  BY con_id,
               owner
     --HAVING TRUNC(SUM(gbytes)) > 0
     )
SELECT pkey , con_id , owner , basic , oltp , query_low ,
       query_high , archive_low , archive_high , total_gb
FROM vcompresstype
ORDER BY total_gb DESC;
spool off
