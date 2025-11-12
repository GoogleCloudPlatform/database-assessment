-- Time series load profile
SELECT
    :v_pkey  || '|' ||
    s.snap_id || '|' ||
    s.instance_number || '|' ||
    ss.begin_interval_time || '|' ||
    SUM(
        CASE
            WHEN metric_name = 'Session Count' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --Session_Count,
    SUM(
        CASE
            WHEN metric_name = 'CPU Usage Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --cpu_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Host CPU Usage Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --host_cpu_centisecs_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Database Time Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --database_time_centisecs_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Executions Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --executions_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'I/O Megabytes per Second' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --io_mb_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'I/O Requests per Second' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --io_req_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Logical Reads Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --logical_reads_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Logons Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --logins_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Network Traffic Volume Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --network_traffic_bytes_per_sec,
    SUM(
        CASE
            WHEN metric_name = 'Redo Generated Per Sec' THEN
                maxval
            ELSE
                0
        END
    ) || '|' || --redo_bytes_per_sec,
    :v_dma_source_id || '|' || --dma_source_id 
    :v_manual_unique_id --dma_manual_id
FROM
    &s_tblprefix._hist_sysmetric_summary s,
    &s_tblprefix._hist_snapshot ss
WHERE  s.snap_id = ss.snap_id
       AND s.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
       AND s.dbid = :v_dbid
       AND s.instance_number = ss.instance_number
       AND s.dbid = ss.dbid
       AND s.metric_name IN ( 'CPU Usage Per Sec', 'Host CPU Usage Per Sec', 'Database Time Per Sec', 'Executions Per Sec', 'I/O Megabytes per Second' ,
                     'I/O Requests per Second', 'Logical Reads Per Sec', 'Logons Per Sec', 'Network Traffic Volume Per Sec', 'Redo Generated Per Sec',
                     'Session Count'
                     )
GROUP BY
    s.snap_id,
    s.instance_number,
    ss.begin_interval_time
ORDER BY 
    ss.begin_interval_time,
    s.instance_number;
