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
exec dbms_application_info.set_action('awrhistsysmetrichist');




WITH vsysmetric AS (
SELECT :v_pkey AS pkey,
       hsm.dbid,
       hsm.instance_number,
       TO_CHAR(dhsnap.snap_time, 'hh24')               AS hour,
       hsm.name                                        AS metric_name,
       null                                            AS metric_unit,
       ROUND(AVG(hsm.delta_value))                     AS avg_value,
       ROUND(STATS_MODE(hsm.delta_value))              AS mode_value,
       ROUND(MEDIAN(hsm.delta_value))                  AS median_value,
       ROUND(MIN(hsm.delta_value))                     AS min_value,
       ROUND(MAX(hsm.delta_value))                     AS max_value,
       ROUND(SUM(hsm.delta_value))                     AS sum_value,
       ROUND(PERCENTILE_CONT(0.05)
         WITHIN GROUP (ORDER BY hsm.delta_value DESC)) AS percentile_95
FROM   (
        SELECT s.snap_id, 
               s.dbid, 
               s.instance_number,  
               s.name,
               s.value,
               NVL(
                   DECODE(
                         GREATEST(value, NVL( LAG(value) OVER ( PARTITION BY s.dbid, s.instance_number, s.name ORDER BY s.snap_id), 0)),
                         value,
                         value - LAG(value) OVER ( PARTITION BY s.dbid, s.instance_number, s.name ORDER BY s.snap_id),
                        0),
                 0) AS delta_value
           FROM perfstat.stats$sysstat s ) hsm
       INNER JOIN stats$snapshot dhsnap
               ON hsm.snap_id = dhsnap.snap_id
                  AND hsm.instance_number = dhsnap.instance_number
                  AND hsm.dbid = dhsnap.dbid
WHERE  dhsnap.snap_time BETWEEN :v_min_snaptime AND :v_max_snaptime
AND hsm.dbid = :v_dbid
GROUP  BY :v_pkey,
          hsm.dbid,
          hsm.instance_number,
          TO_CHAR(dhsnap.snap_time, 'hh24'),
          hsm.name
ORDER  BY hsm.dbid,
          hsm.instance_number,
          hsm.name,
          TO_CHAR(dhsnap.snap_time, 'hh24'))
SELECT pkey  || '|' ||  
       dbid  || '|' ||  
       instance_number  || '|' ||  
       hour  || '|' ||  
       metric_name  || '|' || 
       metric_unit  || '|' ||  
       avg_value  || '|' ||  
       mode_value  || '|' ||  
       median_value  || '|' ||  
       min_value  || '|' ||  
       max_value  || '|' || 
       sum_value  || '|' ||  
       percentile_95  || '|' ||  
       :v_dma_source_id || '|' || --dma_source_id
       :v_manual_unique_id --dma_manual_id
FROM vsysmetric;



