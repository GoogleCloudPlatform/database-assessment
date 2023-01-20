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

spool &outputdir/opdb__awrhistcmdtypes__&v_tag

WITH vcmdtype AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                     AS pkey,
       &v_a_con_id                       AS con_id,
       TO_CHAR(sn.snap_time, 'hh24')     AS hh24,
       ss.command_type, 
       COUNT(1)                          AS cnt,
       ROUND(AVG(buffer_gets))           AS avg_buffer_gets,
       ROUND(AVG(elapsed_time))          AS avg_elapsed_time,
       ROUND(AVG(rows_processed))        AS avg_rows_processed,
       ROUND(AVG(executions))            AS avg_executions,
       ROUND(AVG(cpu_time))              AS avg_cpu_time,
       ROUND(AVG(user_io_wait_time))     AS avg_iowait,
       ROUND(AVG(cluster_wait_time))     AS avg_clwait,
       ROUND(AVG(application_wait_time)) AS avg_apwait,
       ROUND(AVG(concurrency_wait_time)) AS avg_ccwait,
       ROUND(AVG(plsql_exec_time))       AS avg_plsexec_time,
       aa.name                           AS command_name
FROM stats$sql_summary ss
    JOIN stats$snapshot sn
      ON     ss.dbid = sn.dbid
         AND ss.snap_id = sn.snap_id
         AND ss.instance_number = sn.instance_number
    LEFT OUTER join audit_actions aa
                 ON ss.command_type = aa.action
    JOIN v$containers a ON 1=1
WHERE sn.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
GROUP BY '&&v_host'
         || '_'
         || '&&v_dbname'
         || '_'
         || '&&v_hora'  ,
          &v_a_con_id , TO_CHAR(sn.snap_time, 'hh24'),  ss.command_type, aa.name
)
SELECT pkey , con_id , hh24 , command_type , cnt , avg_buffer_gets , avg_elapsed_time ,
       avg_rows_processed , avg_executions , avg_cpu_time , avg_iowait , avg_clwait ,
       avg_apwait , avg_ccwait , avg_plsexec_time, command_name
FROM vcmdtype;
spool off

