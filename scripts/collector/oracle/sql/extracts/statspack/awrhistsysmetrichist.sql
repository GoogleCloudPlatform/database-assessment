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
COLUMN HOUR FORMAT A4
COLUMN METRIC_UNIT FORMAT A15
spool &outputdir/opdb__awrhistsysmetrichist__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|METRIC_NAME|METRIC_UNIT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERC50|PERC75|PERC90|PERC95|PERC100|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsysmetric AS (
SELECT :v_pkey AS pkey,
       hsm.dbid,
       hsm.instance_number,
       TO_CHAR(dhsnap.snap_time, 'hh24')          hour,
       hsm.name as metric_name,
       null as metric_unit,
       ROUND(AVG(hsm.delta_value))                           avg_value,
       ROUND(STATS_MODE(hsm.delta_value))                    mode_value,
       ROUND(MEDIAN(hsm.delta_value))                        median_value,
       ROUND(MIN(hsm.delta_value))                           min_value,
       ROUND(MAX(hsm.delta_value))                           max_value,
       ROUND(SUM(hsm.delta_value))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY hsm.delta_value DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY hsm.delta_value DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY hsm.delta_value DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY hsm.delta_value DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY hsm.delta_value DESC)) AS "PERC100"
FROM   (
        SELECT s.snap_id, s.dbid, s.instance_number, s.name, s.value,
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
WHERE  dhsnap.snap_time BETWEEN '&&v_min_snaptime' AND '&&v_max_snaptime'
AND hsm.dbid = &&v_dbid
GROUP  BY :v_pkey,
          hsm.dbid,
          hsm.instance_number,
          TO_CHAR(dhsnap.snap_time, 'hh24'),
          hsm.name
ORDER  BY hsm.dbid,
          hsm.instance_number,
          hsm.name,
          TO_CHAR(dhsnap.snap_time, 'hh24'))
SELECT pkey , dbid , instance_number , hour , metric_name ,
       metric_unit , avg_value , mode_value , median_value , min_value , max_value ,
	   sum_value , PERC50 , PERC75 , PERC90 , PERC95 , PERC100,
	       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsysmetric;
spool off
COLUMN HOUR CLEAR
COLUMN METRIC_UNIT CLEAR
