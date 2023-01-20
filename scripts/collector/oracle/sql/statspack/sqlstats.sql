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

WITH vsqlstat AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
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
FROM STATS$SQL_SUMMARY a,
     STATS$SNAPSHOT b
WHERE a.snap_id = b.snap_id
AND a.instance_number = b.instance_number
AND a.dbid = b.dbid
AND b.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND b.dbid = &&v_dbid
GROUP BY '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       b.dbid, b.instance_number, force_matching_signature
ORDER BY elapsed_time_total DESC)
SELECT pkey , con_id , dbid , instance_number , force_matching_signature , sql_id ,
       total_executions , total_px_servers_execs , elapsed_time_total , disk_reads_total ,
       physical_read_bytes_total , physical_write_bytes_total , io_offload_elig_bytes_total , io_interconnect_bytes_total ,
       optimized_physical_reads_total , cell_uncompressed_bytes_total , io_offload_return_bytes_total , direct_writes_total ,
       perc_exec_finished , avg_rows , avg_disk_reads , avg_buffer_gets , avg_cpu_time_us , avg_elapsed_us , avg_iowait_us ,
       avg_clwait_us , avg_apwait_us , avg_ccwait_us , avg_plsexec_us , avg_javexec_us
FROM vsqlstat
WHERE rownum < 300;
spool off
