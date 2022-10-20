spool &outputdir/opdb__iofunction__&v_tag

WITH vrawiof AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       snap.begin_interval_time, snap.end_interval_time,
       TO_CHAR(snap.begin_interval_time, 'hh24') hour,
       iof.snap_id, iof.dbid, iof.instance_number, iof.function_id, iof.function_name,
       NVL(DECODE(GREATEST(iof.small_read_megabytes, NVL(LAG(iof.small_read_megabytes)
                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_read_megabytes, iof.small_read_megabytes - LAG(iof.small_read_megabytes)
                                                                       OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_read_mb_delta_value,
       NVL(DECODE(GREATEST(iof.small_write_megabytes, NVL(LAG(iof.small_write_megabytes)
                                                          OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_write_megabytes, iof.small_write_megabytes - LAG(iof.small_write_megabytes)
                                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_write_mb_delta_value,
       NVL(DECODE(GREATEST(iof.small_read_reqs, NVL(LAG(iof.small_read_reqs)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_read_reqs, iof.small_read_reqs - LAG(iof.small_read_reqs)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_read_rq_delta_value,
       NVL(DECODE(GREATEST(iof.small_write_reqs, NVL(LAG(iof.small_write_reqs)
                                                     OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_write_reqs, iof.small_write_reqs - LAG(iof.small_write_reqs)
                                                               OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_write_rq_delta_value,
       NVL(DECODE(GREATEST(iof.large_read_megabytes, NVL(LAG(iof.large_read_megabytes)
                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_read_megabytes, iof.large_read_megabytes - LAG(iof.large_read_megabytes)
                                                                       OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_read_mb_delta_value,
       NVL(DECODE(GREATEST(iof.large_write_megabytes, NVL(LAG(iof.large_write_megabytes)
                                                          OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_write_megabytes, iof.large_write_megabytes - LAG(iof.large_write_megabytes)
                                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_write_mb_delta_value,
       NVL(DECODE(GREATEST(iof.large_read_reqs, NVL(LAG(iof.large_read_reqs)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_read_reqs, iof.large_read_reqs - LAG(iof.large_read_reqs)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_read_rq_delta_value,
       NVL(DECODE(GREATEST(iof.large_write_reqs, NVL(LAG(iof.large_write_reqs)
                                                     OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_write_reqs, iof.large_write_reqs - LAG(iof.large_write_reqs)
                                                               OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_write_rq_delta_value,
       NVL(DECODE(GREATEST(iof.number_of_waits, NVL(LAG(iof.number_of_waits)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.number_of_waits, iof.number_of_waits - LAG(iof.number_of_waits)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS no_iowait_delta_value,
       NVL(DECODE(GREATEST(iof.wait_time, NVL(LAG(iof.wait_time)
                                              OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.wait_time, iof.wait_time - LAG(iof.wait_time)
                                                 OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS tot_watime_delta_value
FROM &v_tblprefix._HIST_IOSTAT_FUNCTION iof
INNER JOIN &v_tblprefix._HIST_SNAPSHOT snap
ON iof.snap_id = snap.snap_id
AND iof.instance_number = snap.instance_number
AND iof.dbid = snap.dbid
WHERE snap.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
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
         within GROUP (ORDER BY tot_watime_delta_value DESC) AS tot_watime_delta_value_P95
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
       ROUND(sm_write_rq_delta_value_P95 + lg_write_rq_delta_value_P95) total_write_req_P95
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
       total_write_req_P95
FROM viof;
spool off
