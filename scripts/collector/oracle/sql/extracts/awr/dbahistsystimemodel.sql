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
exec dbms_application_info.set_action('dbahistsystimemodel');


WITH vtimemodel AS (
SELECT
      :v_pkey as pkey,
      dbid,
      instance_number,
      hour,
      stat_name,
      COUNT(1)                                AS  cnt,
      ROUND(AVG(value))                       AS  avg_value,
      ROUND(STATS_MODE(value))                AS  mode_value,
      ROUND(MEDIAN(value))                    AS  median_value,
      ROUND(MIN(value))                       AS  min_value,
      ROUND(MAX(value))                       AS  max_value,
      ROUND(SUM(value))                       AS  sum_value,
      ROUND(PERCENTILE_CONT(0.05)
        within GROUP (ORDER BY value DESC))   AS percentile_95
FROM (
SELECT
       s.snap_id,
       s.dbid,
       s.instance_number,
       s.begin_interval_time,
       to_char(s.begin_interval_time,'hh24') hour,
       g.stat_name,
       NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                        over (
                                          PARTITION BY s.dbid, s.instance_number, g.stat_name
                                          ORDER BY s.snap_id), 0)), value, value - LAG(value)
                                                                                     over (
                                                                                       PARTITION BY s.dbid, s.instance_number, g.stat_name
                                                                                       ORDER BY s.snap_id),
                                                                    0), 0) AS value
FROM   &s_tblprefix._hist_snapshot s,
       &s_tblprefix._hist_sys_time_model g
WHERE  s.snap_id = g.snap_id
  AND  s.instance_number = g.instance_number
  AND  s.dbid = g.dbid
  AND  s.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
  AND  s.dbid = :v_dbid
)
GROUP BY
      :v_pkey,
      dbid,
      instance_number,
      hour,
      stat_name)
SELECT pkey  || '|' ||  
       dbid  || '|' ||  
       instance_number  || '|' ||  
       hour  || '|' ||  
       stat_name  || '|' ||  
       cnt  || '|' || 
       avg_value  || '|' ||  
       mode_value  || '|' ||  
       median_value  || '|' ||  
       min_value  || '|' || 
       max_value  || '|' || 
       sum_value  || '|' ||  
       percentile_95  || '|' ||  
       :v_dma_source_id || '|' || --dma_source_id
       :v_manual_unique_id --dma_manual_id
FROM vtimemodel;

