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
exec dbms_application_info.set_action('awrsnapdetails');






WITH vawrsnap as (
SELECT  :v_pkey AS pkey,
        dbid, 
        instance_number, 
        hour,
        MIN(snap_id) min_snap_id, 
        MAX(snap_id) max_snap_id,
        TO_CHAR(MIN(begin_interval_time), 'YYYY-MM-DD HH24:MI:SS') min_begin_interval_time,
        TO_CHAR(MAX(begin_interval_time), 'YYYY-MM-DD HH24:MI:SS') max_begin_interval_time,
        COUNT(1) cnt,
        ROUND(SUM(snaps_diff_secs),0) sum_snaps_diff_secs,
        ROUND(AVG(snaps_diff_secs),0) avg_snaps_diff_secs,
        ROUND(MEDIAN(snaps_diff_secs),0) median_snaps_diff_secs,
        ROUND(STATS_MODE(snaps_diff_secs),0) mode_snaps_diff_secs,
        ROUND(MIN(snaps_diff_secs),0) min_snaps_diff_secs,
        ROUND(MAX(snaps_diff_secs),0) max_snaps_diff_secs
FROM (
      SELECT
             s.snap_id,
             s.dbid,
             s.instance_number,
             s.begin_interval_time,
             s.end_interval_time,
             TO_CHAR(s.begin_interval_time,'hh24') hour,
             ( TO_NUMBER(CAST((end_interval_time) AS DATE) - CAST(
                           (begin_interval_time) AS DATE)) * 60 * 60 * 24 ) snaps_diff_secs,
             s.startup_time,
             LAG(s.startup_time,1) OVER (PARTITION BY s.dbid, s.instance_number ORDER BY s.snap_id) lag_startup_time
      FROM   &s_tblprefix._hist_snapshot s
      WHERE  s.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
        AND dbid = :v_dbid
     )
WHERE startup_time = lag_startup_time
GROUP BY :v_pkey, 
         dbid, 
         instance_number, 
         hour
)
SELECT pkey , 
       dbid , 
       instance_number , 
       hour , 
       min_snap_id ,  
       max_snap_id , 
       min_begin_interval_time ,
       max_begin_interval_time , 
       cnt , 
       sum_snaps_diff_secs , 
       avg_snaps_diff_secs , 
       median_snaps_diff_secs ,
       mode_snaps_diff_secs , 
       min_snaps_diff_secs , 
       max_snaps_diff_secs,
       :v_dma_source_id AS dma_source_id, 
       :v_manual_unique_id AS dma_manual_id
FROM vawrsnap;

