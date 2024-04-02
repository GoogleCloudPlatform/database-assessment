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
spool &outputdir/opdb__dbahistsysstat__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|STAT_NAME|CNT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERC50|PERC75|PERC90|PERC95|PERC100|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsysstat AS (
SELECT
       :v_pkey as pkey,
       dbid,
       instance_number,
       hour,
       stat_name,
       COUNT(1)                             cnt,
       ROUND(AVG(value))                           avg_value,
       ROUND(STATS_MODE(value))                    mode_value,
       ROUND(MEDIAN(value))                        median_value,
       ROUND(MIN(value))                           min_value,
       ROUND(MAX(value))                           max_value,
       ROUND(SUM(value))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY value DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY value DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY value DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY value DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY value DESC)) AS "PERC100"
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
                                                                    0), 0) AS VALUE
FROM   &v_tblprefix._hist_snapshot s,
       &v_tblprefix._hist_sysstat g
WHERE  s.snap_id = g.snap_id
       AND s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
       AND s.dbid = &&v_dbid
       AND s.instance_number = g.instance_number
       AND s.dbid = g.dbid
       AND (LOWER(stat_name) LIKE '%db%time%'
       or LOWER(stat_name) LIKE '%redo%time%'
       or LOWER(stat_name) LIKE '%parse%time%'
       or LOWER(stat_name) LIKE 'phy%'
       or LOWER(stat_name) LIKE '%cpu%'
      -- or LOWER(stat_name) LIKE '%hcc%'
       or LOWER(stat_name) LIKE 'cell%phy%'
       or LOWER(stat_name) LIKE 'cell%smart%'
       or LOWER(stat_name) LIKE 'cell%mem%'
       or LOWER(stat_name) LIKE 'cell%flash%'
       or LOWER(stat_name) LIKE 'cell%uncompressed%'
       or LOWER(stat_name) LIKE '%db%block%'
       or LOWER(stat_name) LIKE '%execute%'
      -- or LOWER(stat_name) LIKE '%lob%'
       or LOWER(stat_name) LIKE 'user%'
       or LOWER(stat_name) IN (
                               'physical read total io requests',
                               'physical read total multi block requests',
                               'table fetch by rowid',
                               'table scan blocks gotten',
                               'table scan rows gotten',
                               'consistent gets'))
)
GROUP BY
          :v_pkey,
          dbid,
          instance_number,
          hour,
          stat_name)
SELECT pkey , dbid , instance_number , hour , stat_name , cnt ,
       avg_value , mode_value , median_value , min_value , max_value ,
	   sum_value , perc50 , perc75 , perc90 , perc95 , perc100,
	       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsysstat;
spool off
