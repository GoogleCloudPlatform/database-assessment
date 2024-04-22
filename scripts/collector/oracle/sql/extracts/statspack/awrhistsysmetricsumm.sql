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
COLUMN HOUR          FORMAT A4
COLUMN METRIC_UNIT   FORMAT A15
COLUMN AVG_VALUE     FORMAT 999999999999999999999999999999999999999999999999
COLUMN MODE_VALUE    FORMAT 999999999999999999999999999999999999999999999999
COLUMN MEDIAN_VALUE  FORMAT 999999999999999999999999999999999999999999999999
COLUMN MIN_VALUE     FORMAT 999999999999999999999999999999999999999999999999
COLUMN MAX_VALUE     FORMAT 999999999999999999999999999999999999999999999999
COLUMN SUM_VALUE     FORMAT 999999999999999999999999999999999999999999999999
COLUMN PERC50        FORMAT 999999999999999999999999999999999999999999999999
COLUMN PERC75        FORMAT 999999999999999999999999999999999999999999999999
COLUMN PERC90        FORMAT 999999999999999999999999999999999999999999999999
COLUMN PERC100       FORMAT 999999999999999999999999999999999999999999999999

spool &outputdir/opdb__awrhistsysmetricsumm__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|METRIC_NAME|METRIC_UNIT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERC50|PERC75|PERC90|PERC95|PERC100|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vsysmetricsumm AS (
SELECT :v_pkey AS pkey,
       hsm.dbid,
       hsm.instance_number,
       TO_CHAR(dhsnap.snap_time, 'hh24')          hour,
       hsm.name                              metric_name,
       NULL                               AS metric_unit,
       NULL                                  avg_value,
       null                                  mode_value,
       null                                  median_value,
       NULL                                  min_value,
       NULL                                  max_value,
       null                                  sum_value,
       null                                  "PERC50",
       null                                  "PERC75",
       null                                  "PERC90",
       -- Handle cases where STANDARD_DEVIATION is displayed as NULL but when compared is > .9 repeating but less than 1.
       -- Oberved in 11.2 and 19.3.  Seems to occur when MINVAL < AVERAGE = MAXVAL for 'User Limit %' and 'Session Limit %' metrics.
       -- In most such cases, STARNDARD_DEVIATION = 0, so that is what we will do here.
       --hsm.AVERAGE+(2* CASE WHEN ( standard_deviation > (.999999999999999999999999999) AND standard_deviation < 1 )
       --                      AND ( MINVAL = 0 AND AVERAGE = MAXVAL )  then 0 else standard_deviation end ) "PERC95",
       AVG(value) OVER (PARTITION BY hsm.dbid, hsm.instance_number,  TO_CHAR(dhsnap.snap_time, 'hh24')  , hsm.name) + (2 * STDDEV (value)  OVER (PARTITION BY hsm.dbid, hsm.instance_number,  TO_CHAR(dhsnap.snap_time, 'hh24')  , hsm.name)) AS "PERC95",
       NULL                                   "PERC100"
FROM (
      SELECT s.snap_id, s.dbid, s.instance_number, s.name, s.value,
             NVL(
                 DECODE(
                        GREATEST(value, NVL( LAG(value) OVER ( PARTITION BY s.dbid, s.instance_number, s.name ORDER BY s.snap_id), 0)),
                        value,
                        value - LAG(value) OVER ( PARTITION BY s.dbid, s.instance_number, s.name ORDER BY s.snap_id),
                       0),
                0) AS delta_value
       FROM perfstat.stats$sysstat s )   hsm
       INNER JOIN stats$snapshot dhsnap
               ON hsm.snap_id = dhsnap.snap_id
                  AND hsm.instance_number = dhsnap.instance_number
                  AND hsm.dbid = dhsnap.dbid
WHERE  dhsnap.snap_time BETWEEN '&&v_min_snaptime' AND '&&v_max_snaptime'
AND hsm.dbid = &&v_dbid),
vsysmetricsummperhour as (
    SELECT pkey,
       hsm.dbid,
       hsm.instance_number,
       hour,
       hsm.metric_name,
       hsm.metric_unit,
       ROUND(AVG(hsm.PERC95))                           avg_value,
       ROUND(STATS_MODE(hsm.PERC95))                    mode_value,
       ROUND(MEDIAN(hsm.PERC95))                        median_value,
       ROUND(MIN(hsm.PERC95))                           min_value,
       ROUND(MAX(hsm.PERC95))                           max_value,
       ROUND(SUM(hsm.PERC95))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC100"
    FROM vsysmetricsumm hsm
    GROUP  BY pkey,
            hsm.dbid,
            hsm.instance_number,
            hour,
            hsm.metric_name,
            hsm.metric_unit
)
SELECT pkey , dbid , instance_number , hour , metric_name ,
       metric_unit , avg_value , mode_value , median_value , min_value , max_value ,
	   sum_value , PERC50 , PERC75 , PERC90 , PERC95 , PERC100,
	       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsysmetricsummperhour;
spool off
COLUMN HOUR          CLEAR
COLUMN METRIC_UNIT   CLEAR
COLUMN AVG_VALUE     CLEAR
COLUMN MODE_VALUE    CLEAR
COLUMN MEDIAN_VALUE  CLEAR
COLUMN MIN_VALUE     CLEAR
COLUMN MAX_VALUE     CLEAR
COLUMN SUM_VALUE     CLEAR
COLUMN PERC50        CLEAR
COLUMN PERC75        CLEAR
COLUMN PERC90        CLEAR
COLUMN PERC100       CLEAR
