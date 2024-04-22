/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

COLUMN sp_con_id FORMAT A6 HEADING CON_ID
COLUMN PHYSICAL_READ_BYTES_TOTAL      FORMAT A40
COLUMN PHYSICAL_WRITE_BYTES_TOTAL     FORMAT A40
COLUMN IO_OFFLOAD_ELIG_BYTES_TOTAL    FORMAT A40
COLUMN IO_INTERCONNECT_BYTES_TOTAL    FORMAT A40
COLUMN OPTIMIZED_PHYSICAL_READS_TOTAL FORMAT A40
COLUMN CELL_UNCOMPRESSED_BYTES_TOTAL  FORMAT A40
COLUMN IO_OFFLOAD_RETURN_BYTES_TOTAL  FORMAT A40

spool &outputdir/opdb__sqlstats__&v_tag
prompt PKEY|CON_ID|DBID|INSTANCE_NUMBER|FORCE_MATCHING_SIGNATURE|SQL_ID|TOTAL_EXECUTIONS|TOTAL_PX_SERVERS_EXECS|ELAPSED_TIME_TOTAL|DISK_READS_TOTAL|PHYSICAL_READ_BYTES_TOTAL|PHYSICAL_WRITE_BYTES_TOTAL|IO_OFFLOAD_ELIG_BYTES_TOTAL|IO_INTERCONNECT_BYTES_TOTAL|OPTIMIZED_PHYSICAL_READS_TOTAL|CELL_UNCOMPRESSED_BYTES_TOTAL|IO_OFFLOAD_RETURN_BYTES_TOTAL|DIRECT_WRITES_TOTAL|PERC_EXEC_FINISHED|AVG_ROWS|AVG_DISK_READS|AVG_BUFFER_GETS|AVG_CPU_TIME_US|AVG_ELAPSED_US|AVG_IOWAIT_US|AVG_CLWAIT_US|AVG_APWAIT_US|AVG_CCWAIT_US|AVG_PLSEXEC_US|AVG_JAVEXEC_US|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsqlstat AS(
SELECT :v_pkey AS pkey,
       'N/A' AS con_id,
       b.dbid,
       b.instance_number,
       to_char(force_matching_signature) force_matching_signature,
       min(sql_id) sql_id,
       ROUND(sum(executions)) total_executions,
       ROUND(sum(px_servers_executions)) total_px_servers_execs,
       ROUND(sum(elapsed_time)) elapsed_time_total,
       ROUND(sum(disk_reads)) disk_reads_total,
       NULL physical_read_bytes_total,
       NULL physical_write_bytes_total,
       NULL io_offload_elig_bytes_total,
       NULL io_interconnect_bytes_total,
       NULL optimized_physical_reads_total,
       NULL cell_uncompressed_bytes_total,
       NULL io_offload_return_bytes_total,
       ROUND(sum(direct_writes)) direct_writes_total,
       trunc(decode(sum(executions), 0, 0, (sum(end_of_fetch_count)*100)/sum(executions))) perc_exec_finished,
       trunc(decode(sum(executions), 0, 0, sum(rows_processed)/sum(executions))) avg_rows,
       trunc(decode(sum(executions), 0, 0, sum(disk_reads)/sum(executions))) avg_disk_reads,
       trunc(decode(sum(executions), 0, 0, sum(buffer_gets)/sum(executions))) avg_buffer_gets,
       trunc(decode(sum(executions), 0, 0, sum(cpu_time)/sum(executions))) avg_cpu_time_us,
       trunc(decode(sum(executions), 0, 0, sum(elapsed_time)/sum(executions))) avg_elapsed_us,
       trunc(decode(sum(executions), 0, 0, sum(user_io_wait_time)/sum(executions))) avg_iowait_us,
       trunc(decode(sum(executions), 0, 0, sum(cluster_wait_time)/sum(executions))) avg_clwait_us,
       trunc(decode(sum(executions), 0, 0, sum(application_wait_time)/sum(executions))) avg_apwait_us,
       trunc(decode(sum(executions), 0, 0, sum(concurrency_wait_time)/sum(executions))) avg_ccwait_us,
       trunc(decode(sum(executions), 0, 0, sum(plsql_exec_time)/sum(executions))) avg_plsexec_us,
       trunc(decode(sum(executions), 0, 0, sum(java_exec_time)/sum(executions))) avg_javexec_us
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
     ) a,
     STATS$SNAPSHOT b
WHERE a.snap_id = b.snap_id
AND a.instance_number = b.instance_number
AND a.dbid = b.dbid
AND b.snap_time BETWEEN '&&v_min_snaptime' AND '&&v_max_snaptime'
AND b.dbid = &&v_dbid
GROUP BY :v_pkey,
       b.dbid, b.instance_number, force_matching_signature
ORDER BY elapsed_time_total DESC)
SELECT pkey , con_id AS sp_con_id , dbid , instance_number , force_matching_signature , sql_id ,
       total_executions , total_px_servers_execs , elapsed_time_total , disk_reads_total ,
       physical_read_bytes_total , physical_write_bytes_total , io_offload_elig_bytes_total , io_interconnect_bytes_total ,
       optimized_physical_reads_total , cell_uncompressed_bytes_total , io_offload_return_bytes_total , direct_writes_total ,
       perc_exec_finished , avg_rows , avg_disk_reads , avg_buffer_gets , avg_cpu_time_us , avg_elapsed_us , avg_iowait_us ,
       avg_clwait_us , avg_apwait_us , avg_ccwait_us , avg_plsexec_us , avg_javexec_us,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsqlstat
WHERE rownum < 300;
spool off
COLUMN sp_con_id CLEAR
COLUMN PHYSICAL_READ_BYTES_TOTAL      CLEAR
COLUMN PHYSICAL_WRITE_BYTES_TOTAL     CLEAR
COLUMN IO_OFFLOAD_ELIG_BYTES_TOTAL    CLEAR
COLUMN IO_INTERCONNECT_BYTES_TOTAL    CLEAR
COLUMN OPTIMIZED_PHYSICAL_READS_TOTAL CLEAR
COLUMN CELL_UNCOMPRESSED_BYTES_TOTAL  CLEAR
COLUMN IO_OFFLOAD_RETURN_BYTES_TOTAL  CLEAR
