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
column hour format a4
spool &outputdir/opdb__iofunction__&v_tag

WITH vrawiof AS (
SELECT :v_pkey AS pkey,
       snap.snap_time,
       NULL end_interval_time,
       TO_CHAR(snap.snap_time, 'hh24') hour,
       iof.snap_id, iof.dbid, iof.instance_number, iof.function_id, fn.function_name,
       NVL(DECODE(GREATEST(iof.small_read_megabytes, NVL(LAG(iof.small_read_megabytes)
                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_read_megabytes, iof.small_read_megabytes - LAG(iof.small_read_megabytes)
                                                                       OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS sm_read_mb_delta_value,
       NVL(DECODE(GREATEST(iof.small_write_megabytes, NVL(LAG(iof.small_write_megabytes)
                                                          OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_write_megabytes, iof.small_write_megabytes - LAG(iof.small_write_megabytes)
                                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS sm_write_mb_delta_value,
       NVL(DECODE(GREATEST(iof.small_read_reqs, NVL(LAG(iof.small_read_reqs)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_read_reqs, iof.small_read_reqs - LAG(iof.small_read_reqs)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS sm_read_rq_delta_value,
       NVL(DECODE(GREATEST(iof.small_write_reqs, NVL(LAG(iof.small_write_reqs)
                                                     OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_write_reqs, iof.small_write_reqs - LAG(iof.small_write_reqs)
                                                               OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS sm_write_rq_delta_value,
       NVL(DECODE(GREATEST(iof.large_read_megabytes, NVL(LAG(iof.large_read_megabytes)
                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_read_megabytes, iof.large_read_megabytes - LAG(iof.large_read_megabytes)
                                                                       OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS lg_read_mb_delta_value,
       NVL(DECODE(GREATEST(iof.large_write_megabytes, NVL(LAG(iof.large_write_megabytes)
                                                          OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_write_megabytes, iof.large_write_megabytes - LAG(iof.large_write_megabytes)
                                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS lg_write_mb_delta_value,
       NVL(DECODE(GREATEST(iof.large_read_reqs, NVL(LAG(iof.large_read_reqs)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_read_reqs, iof.large_read_reqs - LAG(iof.large_read_reqs)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS lg_read_rq_delta_value,
       NVL(DECODE(GREATEST(iof.large_write_reqs, NVL(LAG(iof.large_write_reqs)
                                                     OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_write_reqs, iof.large_write_reqs - LAG(iof.large_write_reqs)
                                                               OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS lg_write_rq_delta_value,
       NVL(DECODE(GREATEST(iof.number_of_waits, NVL(LAG(iof.number_of_waits)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.number_of_waits, iof.number_of_waits - LAG(iof.number_of_waits)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS no_iowait_delta_value,
       NVL(DECODE(GREATEST(iof.wait_time, NVL(LAG(iof.wait_time)
                                              OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id), 0)),
                  iof.wait_time, iof.wait_time - LAG(iof.wait_time)
                                                 OVER (PARTITION BY iof.dbid, iof.instance_number, fn.function_name ORDER BY iof.snap_id),0), 0) AS tot_watime_delta_value
FROM STATS$IOSTAT_FUNCTION iof
     INNER JOIN STATS$SNAPSHOT snap
     ON iof.snap_id = snap.snap_id
      AND iof.instance_number = snap.instance_number
      AND iof.dbid = snap.dbid
     INNER JOIN STATS$IOSTAT_FUNCTION_NAME fn
     ON fn.function_id = iof.function_id
WHERE snap.snap_time BETWEEN '&&v_min_snaptime' AND '&&v_max_snaptime'
AND snap.dbid = &&v_dbid),
vperciof AS (
SELECT pkey,
       dbid,
       instance_number,
       hour,
       function_name,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_read_mb_delta_value DESC) AS sm_read_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_write_mb_delta_value DESC) AS sm_write_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_read_rq_delta_value DESC) AS sm_read_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_write_rq_delta_value DESC) AS sm_write_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_read_mb_delta_value DESC) AS lg_read_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_write_mb_delta_value DESC) AS lg_write_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_read_rq_delta_value DESC) AS lg_read_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_write_rq_delta_value DESC) AS lg_write_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY no_iowait_delta_value DESC) AS no_iowait_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY tot_watime_delta_value DESC) AS tot_watime_delta_value_P95,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY sm_read_mb_delta_value DESC) AS sm_read_mb_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY sm_write_mb_delta_value DESC) AS sm_write_mb_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY sm_read_rq_delta_value DESC) AS sm_read_rq_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY sm_write_rq_delta_value DESC) AS sm_write_rq_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY lg_read_mb_delta_value DESC) AS lg_read_mb_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY lg_write_mb_delta_value DESC) AS lg_write_mb_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY lg_read_rq_delta_value DESC) AS lg_read_rq_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY lg_write_rq_delta_value DESC) AS lg_write_rq_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY no_iowait_delta_value DESC) AS no_iowait_delta_value_P100,
       PERCENTILE_CONT(0.00)
         within GROUP (ORDER BY tot_watime_delta_value DESC) AS tot_watime_delta_value_P100
FROM vrawiof
GROUP BY pkey,
         dbid,
         instance_number,
         hour,
         function_name),
viof AS(
SELECT pkey,
       dbid,
       instance_number,
       hour,
       function_name,
       ROUND(sm_read_mb_delta_value_P95) sm_read_mb_delta_value_P95,
       ROUND(sm_write_mb_delta_value_P95) sm_write_mb_delta_value_P95,
       ROUND(sm_read_rq_delta_value_P95) sm_read_rq_delta_value_P95,
       ROUND(sm_write_rq_delta_value_P95) sm_write_rq_delta_value_P95,
       ROUND(lg_read_mb_delta_value_P95) lg_read_mb_delta_value_P95,
       ROUND(lg_write_mb_delta_value_P95) lg_write_mb_delta_value_P95,
       ROUND(lg_read_rq_delta_value_P95) lg_read_rq_delta_value_P95,
       ROUND(lg_write_rq_delta_value_P95) lg_write_rq_delta_value_P95,
       ROUND(no_iowait_delta_value_P95) no_iowait_delta_value_P95,
       ROUND(tot_watime_delta_value_P95) tot_watime_delta_value_P95,
       ROUND(sm_read_mb_delta_value_P95 + lg_read_mb_delta_value_P95) total_reads_mb_P95,
       ROUND(sm_read_rq_delta_value_P95 + lg_read_rq_delta_value_P95) total_reads_req_P95,
       ROUND(sm_write_mb_delta_value_P95 + lg_write_mb_delta_value_P95) total_writes_mb_P95,
       ROUND(sm_write_rq_delta_value_P95 + lg_write_rq_delta_value_P95) total_write_req_P95,
       ROUND(sm_read_mb_delta_value_P100) sm_read_mb_delta_value_P100,
       ROUND(sm_write_mb_delta_value_P100) sm_write_mb_delta_value_P100,
       ROUND(sm_read_rq_delta_value_P100) sm_read_rq_delta_value_P100,
       ROUND(sm_write_rq_delta_value_P100) sm_write_rq_delta_value_P100,
       ROUND(lg_read_mb_delta_value_P100) lg_read_mb_delta_value_P100,
       ROUND(lg_write_mb_delta_value_P100) lg_write_mb_delta_value_P100,
       ROUND(lg_read_rq_delta_value_P100) lg_read_rq_delta_value_P100,
       ROUND(lg_write_rq_delta_value_P100) lg_write_rq_delta_value_P100,
       ROUND(no_iowait_delta_value_P100) no_iowait_delta_value_P100,
       ROUND(tot_watime_delta_value_P100) tot_watime_delta_value_P100,
       ROUND(sm_read_mb_delta_value_P100 + lg_read_mb_delta_value_P100) total_reads_mb_P100,
       ROUND(sm_read_rq_delta_value_P100 + lg_read_rq_delta_value_P100) total_reads_req_P100,
       ROUND(sm_write_mb_delta_value_P100 + lg_write_mb_delta_value_P100) total_writes_mb_P100,
       ROUND(sm_write_rq_delta_value_P100 + lg_write_rq_delta_value_P100) total_write_req_P100
FROM vperciof)
SELECT pkey , dbid , instance_number , hour , function_name ,
       sm_read_mb_delta_value_P95 ,
       sm_write_mb_delta_value_P95 ,
       sm_read_rq_delta_value_P95 ,
       sm_write_rq_delta_value_P95 ,
       lg_read_mb_delta_value_P95 ,
       lg_write_mb_delta_value_P95 ,
       lg_read_rq_delta_value_P95 ,
       lg_write_rq_delta_value_P95 ,
       no_iowait_delta_value_P95 ,
       tot_watime_delta_value_P95 ,
       total_reads_mb_P95 ,
       total_reads_req_P95 ,
       total_writes_mb_P95 ,
       total_write_req_P95,
       sm_read_mb_delta_value_P100 ,
       sm_write_mb_delta_value_P100 ,
       sm_read_rq_delta_value_P100 ,
       sm_write_rq_delta_value_P100 ,
       lg_read_mb_delta_value_P100 ,
       lg_write_mb_delta_value_P100 ,
       lg_read_rq_delta_value_P100 ,
       lg_write_rq_delta_value_P100 ,
       no_iowait_delta_value_P100 ,
       tot_watime_delta_value_P100 ,
       total_reads_mb_P100 ,
       total_reads_req_P100 ,
       total_writes_mb_P100 ,
       total_write_req_P100,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM viof;
spool off
column hour clear
