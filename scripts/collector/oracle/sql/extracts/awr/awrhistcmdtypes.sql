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
exec dbms_application_info.set_action('awrhistcmdtypes');


WITH vcmdtype AS(
SELECT :v_pkey AS pkey,
       &s_a_con_id. AS con_id,
       TO_CHAR(c.begin_interval_time, 'hh24') hh24,
       b.command_type,
       COUNT(1) AS cnt,
       ROUND(AVG(buffer_gets_delta))      AS avg_buffer_gets,
       ROUND(AVG(elapsed_time_delta))     AS avg_elasped_time,
       ROUND(AVG(rows_processed_delta))   AS avg_rows_processed,
       ROUND(AVG(executions_delta))       AS avg_executions,
       ROUND(AVG(cpu_time_delta))         AS avg_cpu_time,
       ROUND(AVG(iowait_delta))           AS avg_iowait,
       ROUND(AVG(clwait_delta))           AS avg_clwait,
       ROUND(AVG(apwait_delta))           AS avg_apwait,
       ROUND(AVG(ccwait_delta))           AS avg_ccwait,
       ROUND(AVG(plsexec_time_delta))     AS avg_plsexec_time,
       aa.name                            AS command_name
FROM   &s_tblprefix._hist_sqlstat a
       INNER JOIN &s_tblprefix._hist_sqltext b
               ON ( &s_a_con_id. = &s_b_con_id.
                    AND a.sql_id = b.sql_id
                    AND a.dbid = b.dbid)
       INNER JOIN &s_tblprefix._hist_snapshot c
               ON ( a.snap_id = c.snap_id
                    AND a.dbid = c.dbid
                    AND a.instance_number = c.instance_number)
       LEFT OUTER join audit_actions aa ON b.command_type = aa.action
WHERE  a.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
  AND  a.dbid = :v_dbid
GROUP  BY :v_pkey,
          &s_a_con_id.,
          TO_CHAR(c.begin_interval_time, 'hh24'),
          b.command_type, 
          aa.name)
SELECT pkey || '|' || 
       con_id || '|' || 
       hh24 || '|' || 
       command_type || '|' || 
       cnt || '|' || 
       avg_buffer_gets || '|' || 
       avg_elasped_time || '|' ||
       avg_rows_processed || '|' || 
       avg_executions || '|' || 
       avg_cpu_time || '|' || 
       avg_iowait || '|' || 
       avg_clwait || '|' ||
       avg_apwait || '|' || 
       avg_ccwait || '|' || 
       avg_plsexec_time || '|' || 
       command_name || '|' ||
       :v_dma_source_id || '|' || --DMA_SOURCE_ID, 
       :v_manual_unique_id --DMA_MANUAL_ID
FROM vcmdtype;

