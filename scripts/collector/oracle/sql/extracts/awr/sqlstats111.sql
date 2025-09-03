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
exec dbms_application_info.set_action('sqlstats111');


WITH vsqlstat AS(
SELECT :v_pkey AS pkey,
       &s_a_con_id. AS con_id,
       b.dbid,
       b.instance_number,
       TO_CHAR(&s_force_matching_sig.) force_matching_signature,
       MIN(sql_id) sql_id,
       ROUND(SUM(executions_delta)) total_executions,
       ROUND(SUM(&s_px_servers_execs_delta.)) total_px_servers_execs,
       ROUND(SUM(elapsed_time_total)) elapsed_time_total,
       ROUND(SUM(disk_reads_delta)) disk_reads_total,
       -1 physical_read_bytes_total,
       -1 physical_write_bytes_total,
       -1 io_offload_elig_bytes_total,
       -1 io_interconnect_bytes_total,
       -1 optimized_physical_reads_total,
       -1 cell_uncompressed_bytes_total,
       -1 io_offload_return_bytes_total,
       ROUND(SUM(direct_writes_delta)) direct_writes_total,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, (SUM(end_of_fetch_count_delta)*100)/SUM(executions_delta))) perc_exec_finished,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(rows_processed_delta)/SUM(executions_delta))) avg_rows,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(disk_reads_delta)/SUM(executions_delta))) avg_disk_reads,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(buffer_gets_delta)/SUM(executions_delta))) avg_buffer_gets,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(cpu_time_delta)/SUM(executions_delta))) avg_cpu_time_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(elapsed_time_delta)/SUM(executions_delta))) avg_elapsed_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(iowait_delta)/SUM(executions_delta))) avg_iowait_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(clwait_delta)/SUM(executions_delta))) avg_clwait_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(apwait_delta)/SUM(executions_delta))) avg_apwait_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(ccwait_delta)/SUM(executions_delta))) avg_ccwait_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(plsexec_time_delta)/SUM(executions_delta))) avg_plsexec_us,
       TRUNC(DECODE(SUM(executions_delta), 0, 0, SUM(javexec_time_delta)/SUM(executions_delta))) avg_javexec_us
FROM &s_tblprefix._hist_sqlstat a, &s_tblprefix._hist_snapshot b
WHERE a.snap_id = b.snap_id
  AND a.instance_number = b.instance_number
  AND a.dbid = b.dbid
  AND b.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
  AND b.dbid = :v_dbid
-- AND &s_a_con_id. = &s_b_con_id.
GROUP BY :v_pkey,
          &s_a_con_id., 
          b.dbid, 
          b.instance_number, 
          &s_force_matching_sig. 
ORDER BY elapsed_time_total DESC)
SELECT pkey , 
       con_id , 
       dbid , 
       instance_number , 
       force_matching_signature , 
       sql_id ,
       total_executions , 
       total_px_servers_execs , 
       elapsed_time_total , 
       disk_reads_total ,
       physical_read_bytes_total , 
       physical_write_bytes_total , 
       io_offload_elig_bytes_total , 
       io_interconnect_bytes_total ,
       optimized_physical_reads_total , 
       cell_uncompressed_bytes_total , 
       io_offload_return_bytes_total ,
       direct_writes_total ,
       perc_exec_finished , 
       avg_rows , 
       avg_disk_reads , 
       avg_buffer_gets , 
       avg_cpu_time_us , 
       avg_elapsed_us , 
       avg_iowait_us ,
       avg_clwait_us , 
       avg_apwait_us , 
       avg_ccwait_us , 
       avg_plsexec_us , 
       avg_javexec_us,
       :v_dma_source_id AS dma_source_id, 
       :v_manual_unique_id AS dma_manual_id
FROM vsqlstat
WHERE rownum < 300;

