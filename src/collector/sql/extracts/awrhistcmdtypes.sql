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
       || '&&v_hora'                          AS pkey,
       &v_a_con_id AS con_id,
       TO_CHAR(c.begin_interval_time, 'hh24') hh24,
       b.command_type,
       COUNT(1)                               cnt,
       ROUND(AVG(buffer_gets_delta))                 AVG_BUFFER_GETS,
       ROUND(AVG(elapsed_time_delta))                AVG_ELASPED_TIME,
       ROUND(AVG(rows_processed_delta))              AVG_ROWS_PROCESSED,
       ROUND(AVG(executions_delta))                  AVG_EXECUTIONS,
       ROUND(AVG(cpu_time_delta))                    AVG_CPU_TIME,
       ROUND(AVG(iowait_delta))                      AVG_IOWAIT,
       ROUND(AVG(clwait_delta))                      AVG_CLWAIT,
       ROUND(AVG(apwait_delta))                      AVG_APWAIT,
       ROUND(AVG(ccwait_delta))                      AVG_CCWAIT,
       ROUND(AVG(plsexec_time_delta))                AVG_PLSEXEC_TIME
FROM   &v_tblprefix._hist_sqlstat a
       inner join &v_tblprefix._hist_sqltext b
               ON ( &v_a_con_id = &v_b_con_id
                    AND a.sql_id = b.sql_id
                    AND a.dbid = b.dbid)
       inner join &v_tblprefix._hist_snapshot c
               ON (
               a.snap_id = c.snap_id
               AND a.dbid = c.dbid
               AND a.instance_number = c.instance_number)
WHERE  a.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND a.dbid = &&v_dbid
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          &v_a_con_id,
          TO_CHAR(c.begin_interval_time, 'hh24'),
          b.command_type)
SELECT pkey , con_id , hh24 , command_type , cnt , avg_buffer_gets , avg_elasped_time ,
       avg_rows_processed , avg_executions , avg_cpu_time , avg_iowait , avg_clwait ,
       avg_apwait , avg_ccwait , avg_plsexec_time
FROM vcmdtype;
spool off
