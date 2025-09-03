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
exec dbms_application_info.set_action('dbahistsysstat');



WITH vsysstat AS (
SELECT
       :v_pkey AS pkey,
       dbid,
       instance_number,
       hour,
       name stat_name,
       COUNT(1)                              AS cnt,
       ROUND(AVG(value))                     AS avg_value,
       ROUND(STATS_MODE(value))              AS mode_value,
       ROUND(MEDIAN(value))                  AS median_value,
       ROUND(MIN(value))                     AS min_value,
       ROUND(MAX(value))                     AS max_value,
       ROUND(SUM(value))                     AS sum_value,
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY value DESC)) AS percentile_95
FROM (
      SELECT
             s.snap_id,
             s.dbid,
             s.instance_number,
             s.snap_time,
             to_char(s.snap_time,'hh24') hour,
             g.name,
             NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                              OVER (
                                                PARTITION BY s.dbid, s.instance_number, g.name
                                                ORDER BY s.snap_id), 0)), value, value - LAG(value)
                                                                                           OVER (
                                                                                             PARTITION BY s.dbid, s.instance_number, g.name
                                                                                             ORDER BY s.snap_id),
                                                                          0), 0) AS value
      FROM   STATS$SNAPSHOT s,
             STATS$SYSSTAT g
      WHERE  s.snap_id = g.snap_id
             AND s.snap_time BETWEEN :v_min_snaptime AND :v_max_snaptime
             AND s.dbid = :v_dbid
             AND s.instance_number = g.instance_number
             AND s.dbid = g.dbid
             AND (LOWER(name) LIKE '%db%time%'
                  OR LOWER(name) LIKE '%redo%time%'
                  OR LOWER(name) LIKE '%parse%time%'
                  OR LOWER(name) LIKE 'phy%'
                  OR LOWER(name) LIKE '%cpu%'
               -- or LOWER(name) LIKE '%hcc%'
                  OR LOWER(name) LIKE 'cell%phy%'
                  OR LOWER(name) LIKE 'cell%smart%'
                  OR LOWER(name) LIKE 'cell%mem%'
                  OR LOWER(name) LIKE 'cell%flash%'
                  OR LOWER(name) LIKE 'cell%uncompressed%'
                  OR LOWER(name) LIKE '%db%block%'
                  OR LOWER(name) LIKE '%execute%'
               -- or LOWER(name) LIKE '%lob%'
                  OR LOWER(name) LIKE 'user%'
                 )
)
GROUP BY
         :v_pkey,
         dbid,
         instance_number,
         hour,
         name)
SELECT pkey,
       dbid,
       instance_number,
       hour,
       stat_name,
       cnt ,
       avg_value,
       mode_value,
       median_value,
       min_value,
       max_value ,
       sum_value,
       percentile_95 ,
       :v_dma_source_id AS dma_source_id,
       :v_manual_unique_id AS dma_manual_id
FROM vsysstat;



