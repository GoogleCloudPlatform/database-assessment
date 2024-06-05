--
-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License").
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--

COLUMN sp_con_id FORMAT A6 HEADING CON_ID

spool &outputdir/opdb__awrhistcmdtypes__&v_tag
prompt PKEY|CON_ID|HH|COMMAND_TYPE|CNT|AVG_BUFFER_GETS|AVG_ELASPED_TIME|AVG_ROWS_PROCESSED|AVG_EXECUTIONS|AVG_CPU_TIME|AVG_IOWAIT|AVG_CLWAIT|AVG_APWAIT|AVG_CCWAIT|AVG_PLSEXEC_TIME|COMMAND_NAME|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vcmdtype AS(
SELECT :v_pkey AS pkey,
       'N/A'                       AS con_id,
       TO_CHAR(sn.snap_time, 'hh24')     AS hh24,
       ss.command_type,
       COUNT(1)                          AS cnt,
       ROUND(AVG(delta_buffer_gets))           AS avg_buffer_gets,
       ROUND(AVG(delta_elapsed_time))          AS avg_elapsed_time,
       ROUND(AVG(delta_rows_processed))        AS avg_rows_processed,
       ROUND(AVG(delta_executions))            AS avg_executions,
       ROUND(AVG(delta_cpu_time))              AS avg_cpu_time,
       ROUND(AVG(delta_user_io_wait_time))     AS avg_iowait,
       ROUND(AVG(delta_cluster_wait_time))     AS avg_clwait,
       ROUND(AVG(delta_application_wait_time)) AS avg_apwait,
       ROUND(AVG(delta_concurrency_wait_time)) AS avg_ccwait,
       ROUND(AVG(delta_plsql_exec_time))       AS avg_plsexec_time,
       aa.name                           AS command_name
FROM
(
select snap_id, dbid, instance_number, text_subset, old_hash_value, command_type, force_matching_signature, sql_id,
s.executions,
   NVL(
       DECODE(
              GREATEST(executions, NVL( LAG(executions) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              executions,
              executions - LAG(executions) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_executions,
      px_servers_executions,
      NVL(
       DECODE(
              GREATEST(px_servers_executions, NVL( LAG(px_servers_executions) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              px_servers_executions,
              px_servers_executions - LAG(px_servers_executions) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_px_servers_executions,
      elapsed_time,
      NVL(
       DECODE(
              GREATEST(elapsed_time, NVL( LAG(elapsed_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              elapsed_time,
              elapsed_time - LAG(elapsed_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_elapsed_time,
      disk_reads,
            NVL(
       DECODE(
              GREATEST(disk_reads, NVL( LAG(disk_reads) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              disk_reads,
              disk_reads - LAG(disk_reads) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_disk_reads,
      direct_writes,
            NVL(
       DECODE(
              GREATEST(direct_writes, NVL( LAG(direct_writes) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              direct_writes,
              direct_writes - LAG(direct_writes) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_direct_writes,
      end_of_fetch_count,
            NVL(
       DECODE(
              GREATEST(end_of_fetch_count, NVL( LAG(end_of_fetch_count) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              end_of_fetch_count,
              end_of_fetch_count - LAG(end_of_fetch_count) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_end_of_fetch_count,
      rows_processed,
            NVL(
       DECODE(
              GREATEST(rows_processed, NVL( LAG(rows_processed) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              rows_processed,
              rows_processed - LAG(rows_processed) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_rows_processed,
      buffer_gets,
            NVL(
       DECODE(
              GREATEST(buffer_gets, NVL( LAG(buffer_gets) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              buffer_gets,
              buffer_gets - LAG(buffer_gets) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_buffer_gets,
      cpu_time,
            NVL(
       DECODE(
              GREATEST(cpu_time, NVL( LAG(cpu_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              cpu_time,
              cpu_time - LAG(cpu_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_cpu_time,
      user_io_wait_time,
            NVL(
       DECODE(
              GREATEST(user_io_wait_time, NVL( LAG(user_io_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              user_io_wait_time,
              user_io_wait_time - LAG(user_io_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_user_io_wait_time,
      cluster_wait_time,
            NVL(
       DECODE(
              GREATEST(cluster_wait_time, NVL( LAG(cluster_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              cluster_wait_time,
              cluster_wait_time - LAG(cluster_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_cluster_wait_time,
      application_wait_time,
            NVL(
       DECODE(
              GREATEST(application_wait_time, NVL( LAG(application_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              application_wait_time,
              application_wait_time - LAG(application_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_application_wait_time,
      concurrency_wait_time,
            NVL(
       DECODE(
              GREATEST(concurrency_wait_time, NVL( LAG(concurrency_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              concurrency_wait_time,
              concurrency_wait_time - LAG(concurrency_wait_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_concurrency_wait_time,
      plsql_exec_time,
            NVL(
       DECODE(
              GREATEST(plsql_exec_time, NVL( LAG(plsql_exec_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              plsql_exec_time,
              plsql_exec_time - LAG(plsql_exec_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_plsql_exec_time,
      java_exec_time,
            NVL(
       DECODE(
              GREATEST(java_exec_time, NVL( LAG(java_exec_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id), 0)),
              java_exec_time,
              java_exec_time - LAG(java_exec_time) OVER ( PARTITION BY s.dbid, s.instance_number, text_subset, old_hash_value, command_type, force_matching_signature ORDER BY s.snap_id),
             0),
      0) AS delta_java_exec_time
From STATS$SQL_SUMMARY s
     ) ss
    JOIN stats$snapshot sn
      ON     ss.dbid = sn.dbid
         AND ss.snap_id = sn.snap_id
         AND ss.instance_number = sn.instance_number
    LEFT OUTER join audit_actions aa
                 ON ss.command_type = aa.action
WHERE sn.snap_time BETWEEN '&&v_min_snaptime' AND '&&v_max_snaptime'
GROUP BY :v_pkey,
          'N/A' , TO_CHAR(sn.snap_time, 'hh24'),  ss.command_type, aa.name
)
SELECT pkey , con_id AS sp_con_id, hh24 , command_type , cnt , avg_buffer_gets , avg_elapsed_time ,
       avg_rows_processed , avg_executions , avg_cpu_time , avg_iowait , avg_clwait ,
       avg_apwait , avg_ccwait , avg_plsexec_time, command_name,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vcmdtype;
spool off
COLUMN sp_con_id CLEAR
