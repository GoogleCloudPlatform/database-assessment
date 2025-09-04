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
                     TO_CHAR(os.snap_time, 'hh24') hh24,
                     os.stat_name,
                     os.value cumulative_value,
                     os.delta_value,
                     ( (os.snap_time) - LAG((os.snap_time)) OVER (PARTITION BY os.dbid, os.instance_number, os.stat_name ORDER BY os.snap_id)) * 60 * 60 * 24 AS snap_total_secs,
                     PERCENTILE_CONT(0.05)
                       within GROUP (ORDER BY os.delta_value DESC) OVER (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.snap_time, 'hh24'), os.stat_name) AS percentile_95 --,
                     -- MAX(os.delta_value) AS peak
              FROM (SELECT snap.snap_time, 
                           s.snap_id, 
                           s.dbid, 
                           s.instance_number, 
                           s.value, 
                           osname.stat_name,
                           NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                                          OVER (
                                                                PARTITION BY s.dbid, s.instance_number, osname.stat_name ORDER BY s.snap_id), 0)), 
                                      value, value - LAG(value) OVER (
                                                                      PARTITION BY s.dbid, s.instance_number, osname.stat_name ORDER BY s.snap_id),
                                      0), 
                               0) AS delta_value
                    FROM stats$osstat s
                         INNER JOIN stats$snapshot snap
                                 ON s.snap_id = snap.snap_id
                                AND s.instance_number = snap.instance_number
                                AND s.dbid = snap.dbid
                         INNER JOIN 
&s_statsosstatname.  
                            osname
                                ON s.osstat_id = osname.osstat_id
                    WHERE snap.snap_time BETWEEN (SELECT max(snap_time) FROM  stats$snapshot WHERE snap_time < :v_min_snaptime  ) AND :v_max_snaptime
                      AND s.dbid = :v_dbid
                    ) os 
) ,
vossummary AS (
               SELECT :v_pkey AS pkey,
                      dbid,
                      instance_number,
                      hh24,
                      stat_name,
                      ROUND(SUM(snap_total_secs))       hh24_total_secs,
                      ROUND(AVG(cumulative_value))      cumulative_value,
                      ROUND(AVG(delta_value))           avg_value,
                      ROUND(STATS_MODE(delta_value))    mode_value,
                      ROUND(MEDIAN(delta_value))        median_value,
                      ROUND(AVG(percentile_95))         percentile_95,
                      --ROUND(AVG(peak))                  averaged_peak,
                      ROUND(MIN(delta_value))           min_value,
                      ROUND(MAX(delta_value))           max_value,
                      ROUND(SUM(delta_value))           sum_value,
                      COUNT(1)             count
               FROM  v_osstat_all
               GROUP BY :v_pkey,
                        dbid,
                        instance_number,
                        hh24,
                        stat_name
)
SELECT pkey, 
       dbid, 
       instance_number, 
       hh24, 
       stat_name, 
       hh24_total_secs ,
       cumulative_value, 
       avg_value, 
       mode_value, 
       median_value, 
       percentile_95, 
--       averaged_peak,
       min_value, 
       max_value, 
       sum_value, 
       count,
       :v_dma_source_id AS dma_source_id, 
       :v_manual_unique_id AS dma_manual_id
FROM vossummary;


