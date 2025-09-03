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
exec dbms_application_info.set_action('awrhistosstat');


WITH v_osstat_all
     AS (SELECT os.dbid,
                     os.instance_number,
                     TO_CHAR(os.begin_interval_time, 'hh24') hh24,
                     os.stat_name,
                     os.value cumulative_value,
                     os.delta_value,
                     ( TO_NUMBER(CAST(os.end_interval_time AS DATE) - CAST(os.begin_interval_time AS DATE)) * 60 * 60 * 24 ) AS snap_total_secs,
                     PERCENTILE_CONT(0.05)
                       WITHIN GROUP (ORDER BY os.delta_value DESC) OVER (
                         PARTITION BY os.dbid, os.instance_number,
                                      TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS percentile_95,
                     MAX(os.delta_value) OVER (
                         PARTITION BY os.dbid, os.instance_number,
                                      TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS peak
              FROM (SELECT snap.begin_interval_time, 
                           snap.end_interval_time, 
                           s.*,
                           CASE WHEN s.stat_name IN ('IDLE_TIME' ,'BUSY_TIME' ,'USER_TIME' ,'SYS_TIME' ,'IOWAIT_TIME' ,'NICE_TIME' ,'RSRC_MGR_CPU_WAIT_TIME' ,'VM_IN_BYTES' ,'VM_OUT_BYTES')
                                     THEN
                                         NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                         OVER (
                                         PARTITION BY s.dbid, s.instance_number, s.stat_name
                                         ORDER BY s.snap_id), 0)), value, value - LAG(value)
                                            OVER (
                                            PARTITION BY s.dbid, s.instance_number, s.stat_name
                                            ORDER BY s.snap_id),
                                         0), 0)
                                ELSE s.value 
                           END AS delta_value
                    FROM &s_tblprefix._hist_osstat s
                         INNER JOIN &s_tblprefix._hist_snapshot snap
                                ON s.snap_id = snap.snap_id
                                AND s.instance_number = snap.instance_number
                                AND s.dbid = snap.dbid
                    WHERE s.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
                    AND s.dbid = :v_dbid
                    ) os 
        ) ,
vossummary AS (
SELECT :v_pkey AS pkey,
       dbid,
       instance_number,
       hh24,
       stat_name,
       ROUND(SUM(snap_total_secs))    AS hh24_total_secs,
       ROUND(AVG(cumulative_value))   AS cumulative_value,
       ROUND(AVG(delta_value))        AS avg_value,
       ROUND(STATS_MODE(delta_value)) AS mode_value,
       ROUND(MEDIAN(delta_value))     AS median_value,
       ROUND(AVG(percentile_95))      AS percentile_95,
       ROUND(AVG(peak))               AS averaged_peak,
       ROUND(MIN(delta_value))        AS min_value,
       ROUND(MAX(delta_value))        AS max_value,
       ROUND(SUM(delta_value))        AS sum_value,
       COUNT(1)                       AS count
FROM   v_osstat_all
GROUP  BY :v_pkey,
          dbid,
          instance_number,
          hh24,
          stat_name)
SELECT pkey , 
       dbid , 
       instance_number , 
       hh24 , 
       stat_name , 
       hh24_total_secs ,
       cumulative_value , 
       avg_value , 
       mode_value , 
       median_value , 
       percentile_95 , 
       averaged_peak ,
       min_value , 
       max_value , 
       sum_value , 
       count,
       :v_dma_source_id AS dma_source_id, 
       :v_manual_unique_id AS dma_manual_id
FROM vossummary;

