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
spool &outputdir/opdb__sqlstats__&v_tag
prompt PKEY|CON_ID|DBID|INSTANCE_NUMBER|FORCE_MATCHING_SIGNATURE|SQL_ID|TOTAL_EXECUTIONS|TOTAL_PX_SERVERS_EXECS|ELAPSED_TIME_TOTAL|DISK_READS_TOTAL|PHYSICAL_READ_BYTES_TOTAL|PHYSICAL_WRITE_BYTES_TOTAL|IO_OFFLOAD_ELIG_BYTES_TOTAL|IO_INTERCONNECT_BYTES_TOTAL|OPTIMIZED_PHYSICAL_READS_TOTAL|CELL_UNCOMPRESSED_BYTES_TOTAL|IO_OFFLOAD_RETURN_BYTES_TOTAL|DIRECT_WRITES_TOTAL|PERC_EXEC_FINISHED|AVG_ROWS|AVG_DISK_READS|AVG_BUFFER_GETS|AVG_CPU_TIME_US|AVG_ELAPSED_US|AVG_IOWAIT_US|AVG_CLWAIT_US|AVG_APWAIT_US|AVG_CCWAIT_US|AVG_PLSEXEC_US|AVG_JAVEXEC_US|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsqlstat AS(
SELECT :v_pkey AS pkey,
       &v_a_con_id AS con_id,
       b.dbid,
       b.instance_number,
       to_char(force_matching_signature) force_matching_signature,
       min(sql_id) sql_id,
       ROUND(sum(executions_delta)) total_executions,
       ROUND(sum(px_servers_execs_delta)) total_px_servers_execs,
       ROUND(sum(elapsed_time_total)) elapsed_time_total,
       ROUND(sum(disk_reads_delta)) disk_reads_total,
       -1 physical_read_bytes_total,
       -1 physical_write_bytes_total,
       -1 io_offload_elig_bytes_total,
       -1 io_interconnect_bytes_total,
       -1 optimized_physical_reads_total,
       -1 cell_uncompressed_bytes_total,
       -1 io_offload_return_bytes_total,
       ROUND(sum(direct_writes_delta)) direct_writes_total,
       trunc(decode(sum(executions_delta), 0, 0, (sum(end_of_fetch_count_delta)*100)/sum(executions_delta))) perc_exec_finished,
       trunc(decode(sum(executions_delta), 0, 0, sum(rows_processed_delta)/sum(executions_delta))) avg_rows,
       trunc(decode(sum(executions_delta), 0, 0, sum(disk_reads_delta)/sum(executions_delta))) avg_disk_reads,
       trunc(decode(sum(executions_delta), 0, 0, sum(buffer_gets_delta)/sum(executions_delta))) avg_buffer_gets,
       trunc(decode(sum(executions_delta), 0, 0, sum(cpu_time_delta)/sum(executions_delta))) avg_cpu_time_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(elapsed_time_delta)/sum(executions_delta))) avg_elapsed_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(iowait_delta)/sum(executions_delta))) avg_iowait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(clwait_delta)/sum(executions_delta))) avg_clwait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(apwait_delta)/sum(executions_delta))) avg_apwait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(ccwait_delta)/sum(executions_delta))) avg_ccwait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(plsexec_time_delta)/sum(executions_delta))) avg_plsexec_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(javexec_time_delta)/sum(executions_delta))) avg_javexec_us
FROM &v_tblprefix._hist_sqlstat a, &v_tblprefix._hist_snapshot b
WHERE a.snap_id = b.snap_id
AND a.instance_number = b.instance_number
AND a.dbid = b.dbid
AND b.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND b.dbid = &&v_dbid
-- AND &v_a_con_id = &v_b_con_id
--and t.command_type <> 47
-- and s.executions_total > 100
GROUP BY :v_pkey,
       &v_a_con_id, b.dbid, b.instance_number, force_matching_signature
ORDER BY elapsed_time_total DESC)
SELECT pkey , con_id , dbid , instance_number , force_matching_signature , sql_id ,
       total_executions , total_px_servers_execs , elapsed_time_total , disk_reads_total ,
       physical_read_bytes_total , physical_write_bytes_total , io_offload_elig_bytes_total , io_interconnect_bytes_total ,
       optimized_physical_reads_total , cell_uncompressed_bytes_total , io_offload_return_bytes_total ,
       direct_writes_total ,
       perc_exec_finished , avg_rows , avg_disk_reads , avg_buffer_gets , avg_cpu_time_us , avg_elapsed_us , avg_iowait_us ,
       avg_clwait_us , avg_apwait_us , avg_ccwait_us , avg_plsexec_us , avg_javexec_us,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsqlstat
WHERE rownum < 300;
spool off
