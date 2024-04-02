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
set echo on
spool &outputdir/opdb__awrhistosstat__&v_tag
prompt PKEY|DBID|INSTANCE_NUMBER|HH|STAT_NAME|HH24_TOTAL_SECS|CUMULATIVE_VALUE|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|PERC50|PERC75|PERC90|PERC95|PERC100|MIN_VALUE|MAX_VALUE|SUM_VALUE|COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH v_osstat_all
     AS (SELECT os.dbid,
                     os.instance_number,
                     TO_CHAR(os.begin_interval_time, 'hh24') hh24,
                     os.stat_name,
                     os.value cumulative_value,
                     os.delta_value,
                     ( TO_NUMBER(CAST(os.end_interval_time AS DATE) - CAST(os.begin_interval_time AS DATE)) * 60 * 60 * 24 )
                        snap_total_secs,
                     PERCENTILE_CONT(0.5)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC50",
                     PERCENTILE_CONT(0.25)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC75",
                     PERCENTILE_CONT(0.1)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC90",
                     PERCENTILE_CONT(0.05)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC95",
                     PERCENTILE_CONT(0)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC100"
              FROM (SELECT snap.begin_interval_time, snap.end_interval_time, s.*,
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
			ELSE s.value END AS delta_value
                    FROM &v_tblprefix._hist_osstat s
                         inner join &v_tblprefix._hist_snapshot snap
                         ON s.snap_id = snap.snap_id
                         AND s.instance_number = snap.instance_number
                         AND s.dbid = snap.dbid
                    WHERE s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
                    AND s.dbid = &&v_dbid) os ) ,
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
       ROUND(AVG(perc50))                PERC50,
       ROUND(AVG(perc75))                PERC75,
       ROUND(AVG(perc90))                PERC90,
       ROUND(AVG(perc95))                PERC95,
       ROUND(AVG(perc100))               PERC100,
       ROUND(MIN(delta_value))           min_value,
       ROUND(MAX(delta_value))           max_value,
       ROUND(SUM(delta_value))           sum_value,
       COUNT(1)             count
FROM   v_osstat_all
GROUP  BY :v_pkey,
          dbid,
          instance_number,
          hh24,
          stat_name)
SELECT pkey , dbid , instance_number , hh24 , stat_name , hh24_total_secs ,
       cumulative_value , avg_value , mode_value , median_value , PERC50 , PERC75 , PERC90 , PERC95 , PERC100 ,
	     min_value , max_value , sum_value , count,
	       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vossummary;
spool off
