SELECT     b.hostname,
           a.hour,
           SUM(average_active_session_perc95) average_active_session_perc95,
           SUM(average_active_session_max)    average_active_session_max,
           SUM(cpu_usage_per_sec_perc95)      cpu_usage_per_sec_perc95,
           SUM(cpu_usage_per_sec_max)         cpu_usage_per_sec_max,
           SUM(bkgr_cpu_usage_per_sec_perc95) bkgr_cpu_usage_per_sec_perc95,
           MAX(bkgr_cpu_usage_per_sec_max)    bkgr_cpu_usage_per_sec_max,
           SUM(host_cpu_usage_per_sec_perc95) host_cpu_usage_per_sec_perc95,
           SUM(host_cpu_usage_per_sec_max)    host_cpu_usage_per_sec_max,
           SUM(executions_per_sec_perc95)     executions_per_sec_perc95,
           SUM(executions_per_sec_max)        executions_per_sec_max,
           SUM(io_mbytes_per_sec_perc95)      io_mbytes_per_sec_perc95,
           SUM(io_mbytes_per_sec_max)         io_mbytes_per_sec_max,
           SUM(io_req_per_sec_perc95)         io_req_per_sec_perc95,
           SUM(io_req_per_sec_max)            io_req_per_sec_max,
           SUM(logons_per_sec_perc95)         logons_per_sec_perc95,
           SUM(logons_per_sec_max)            logons_per_sec_max,
           SUM(phy_rds_per_sec_perc95)        phy_rds_per_sec_perc95,
           SUM(phy_rds_per_sec_max)           phy_rds_per_sec_max,
           SUM(phy_wts_per_sec_perc95)        phy_wts_per_sec_perc95,
           SUM(phy_wts_per_sec_max)           phy_wts_per_sec_max,
           SUM(redo_per_sec_perc95)           redo_per_sec_perc95,
           SUM(redo_per_sec_max)              redo_per_sec_max,
           SUM(sql_rt_per_sec_perc95)         sql_rt_per_sec_perc95,
           SUM(sql_rt_per_sec_max)            sql_rt_per_sec_max,
           SUM(transac_per_sec_perc95)        transac_per_sec_perc95,
           SUM(transac_per_sec_max)           transac_per_sec_max
FROM       (
                  SELECT TRIM(pkey)            ckey,
                         TRIM(con_id)          con_id,
                         TRIM(dbid)            dbid,
                         TRIM(instance_number) instance_number,
                         TRIM(hour)            hour,
                         CASE TRIM(metric_name)
                                WHEN 'Average Active Sessions' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS average_active_session_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Average Active Sessions' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS average_active_session_max,
                         CASE TRIM(metric_name)
                                WHEN 'CPU Usage Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS cpu_usage_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'CPU Usage Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS cpu_usage_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Background CPU Usage Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS bkgr_cpu_usage_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Background CPU Usage Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS bkgr_cpu_usage_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Host CPU Usage Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS host_cpu_usage_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Host CPU Usage Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS host_cpu_usage_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Executions Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS executions_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Executions Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS executions_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'I/O Megabytes per Second' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS io_mbytes_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'I/O Megabytes per Second' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS io_mbytes_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'I/O Requests per Second' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS io_req_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'I/O Requests per Second' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS io_req_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Logons Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS logons_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Logons Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS logons_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Physical Reads Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS phy_rds_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Physical Reads Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS phy_rds_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Physical Writes Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS phy_wts_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Physical Writes Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS phy_wts_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'Redo Generated Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS redo_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'Redo Generated Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS redo_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'SQL Service Response Time' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS sql_rt_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'SQL Service Response Time' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS sql_rt_per_sec_max,
                         CASE TRIM(metric_name)
                                WHEN 'User Transaction Per Sec' THEN CAST(TRIM(a.perc95) AS INT64)
                         END AS transac_per_sec_perc95,
                         CASE TRIM(metric_name)
                                WHEN 'User Transaction Per Sec' THEN CAST(TRIM(a.perc100) AS INT64)
                         END AS transac_per_sec_max
                  FROM   mydataset.awrhistsysmetrichist a ) a
inner join mydataset.vinstsummary b
ON         a.ckey = b.ckey
AND        a.instance_number = b.inst_id
GROUP BY   b.hostname,
           a.hour;
