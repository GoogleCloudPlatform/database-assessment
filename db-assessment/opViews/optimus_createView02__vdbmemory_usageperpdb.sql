SELECT a.ckey,
       a.hostname,
       a.inst_id,
       a.con_id,
       a.memory_max_target_gb,
       a.memory_target_gb,
       a.sga_max_size_gb,
       a.sga_target_gb,
       a.pga_aggregate_target_gb,
       CASE memory_max_target_gb
              WHEN 0.0 THEN sga_max_size_gb+pga_aggregate_target_gb
              ELSE memory_max_target_gb
       END db_total_memory_gb
FROM   (
                  SELECT     a.ckey,
                             b.hostname,
                             a.inst_id,
                             a.con_id,
                             ROUND(SUM(a.memory_max_target)   /1024/1024/1024,1) memory_max_target_gb,
                             ROUND(SUM(a.memory_target)       /1024/1024/1024,1) memory_target_gb,
                             ROUND(SUM(a.sga_max_size)        /1024/1024/1024,1) sga_max_size_gb,
                             ROUND(SUM(a.sga_target)          /1024/1024/1024,1) sga_target_gb,
                             ROUND(SUM(a.pga_aggregate_target)/1024/1024/1024,1) pga_aggregate_target_gb
                  FROM       (
                                    SELECT TRIM(a.pkey)    ckey,
                                           TRIM(a.inst_id) inst_id,
                                           TRIM(a.con_id)  con_id,
                                           CASE TRIM(name)
                                                  WHEN 'memory_max_target' THEN CAST(TRIM(a.value) AS INT64)
                                           END AS memory_max_target,
                                           CASE TRIM(name)
                                                  WHEN 'memory_target' THEN CAST(TRIM(a.value) AS INT64)
                                           END AS memory_target,
                                           CASE TRIM(name)
                                                  WHEN 'sga_max_size' THEN CAST(TRIM(a.value) AS INT64)
                                           END AS sga_max_size,
                                           CASE TRIM(name)
                                                  WHEN 'sga_target' THEN CAST(TRIM(a.value) AS INT64)
                                           END AS sga_target,
                                           CASE TRIM(name)
                                                  WHEN 'pga_aggregate_target' THEN CAST(TRIM(a.value) AS INT64)
                                           END AS pga_aggregate_target
                                    FROM   ${dataset}.dbparameters a
                                    WHERE  trim(name) IN ('memory_max_target',
                                                          'memory_target',
                                                          'sga_max_size',
                                                          'sga_target',
                                                          'pga_aggregate_target') ) a
                  inner join ${dataset}.vinstsummary b
                  ON         a.ckey = b.ckey
                  AND        a.inst_id = b.inst_id
                  GROUP BY   a.ckey,
                             b.hostname,
                             a.inst_id,
                             a.con_id ) a;
