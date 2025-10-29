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
spool &outputdir/opdb__dbahistsysstat__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|STAT_NAME|CNT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERC50|PERC75|PERC90|PERC95|PERC100|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsysstat AS (
SELECT
       :v_pkey as pkey,
       dbid,
       instance_number,
       hour,
       name stat_name,
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
       s.snap_time,
       to_char(s.snap_time,'hh24') hour,
       g.name,
       NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                        over (
                                          PARTITION BY s.dbid, s.instance_number, g.name
                                          ORDER BY s.snap_id), 0)), value, value - LAG(value)
                                                                                     over (
                                                                                       PARTITION BY s.dbid, s.instance_number, g.name
                                                                                       ORDER BY s.snap_id),
                                                                    0), 0) AS VALUE
FROM   STATS$SNAPSHOT s,
       STATS$SYSSTAT g
WHERE  s.snap_id = g.snap_id
       AND s.snap_time BETWEEN '&&v_min_snaptime' AND '&&v_max_snaptime'
       AND s.dbid = '&&v_dbid'
       AND s.instance_number = g.instance_number
       AND s.dbid = g.dbid
       AND (LOWER(name) LIKE '%db%time%'
       or LOWER(name) LIKE '%redo%time%'
       or LOWER(name) LIKE '%parse%time%'
       or LOWER(name) LIKE 'phy%'
       or LOWER(name) LIKE '%cpu%'
      -- or LOWER(name) LIKE '%hcc%'
       or LOWER(name) LIKE 'cell%phy%'
       or LOWER(name) LIKE 'cell%smart%'
       or LOWER(name) LIKE 'cell%mem%'
       or LOWER(name) LIKE 'cell%flash%'
       or LOWER(name) LIKE 'cell%uncompressed%'
       or LOWER(name) LIKE '%db%block%'
       or LOWER(name) LIKE '%execute%'
      -- or LOWER(name) LIKE '%lob%'
       or LOWER(name) LIKE 'user%')
)
GROUP BY
          :v_pkey,
          dbid,
          instance_number,
          hour,
          name)
SELECT pkey , dbid , instance_number , hour , stat_name , cnt ,
       avg_value , mode_value , median_value , min_value , max_value ,
	   sum_value , perc50 , perc75 , perc90 , perc95 , perc100,
	       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsysstat;

spool off
COLUMN HOUR CLEAR
