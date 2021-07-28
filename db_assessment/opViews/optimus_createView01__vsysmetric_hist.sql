SELECT   ckey,
         con_id,
         dbid,
         instance_number,
         hour,
         Sum(average_active_session_perc95) average_active_session_perc95,
         Sum(average_active_session_max)    average_active_session_max,
         Sum(cpu_usage_per_sec_perc95)      cpu_usage_per_sec_perc95,
         Sum(cpu_usage_per_sec_max)         cpu_usage_per_sec_max,
         Sum(bkgr_cpu_usage_per_sec_perc95) bkgr_cpu_usage_per_sec_perc95,
         Max(bkgr_cpu_usage_per_sec_max)    bkgr_cpu_usage_per_sec_max,
         Sum(host_cpu_usage_per_sec_perc95) host_cpu_usage_per_sec_perc95,
         Sum(host_cpu_usage_per_sec_max)    host_cpu_usage_per_sec_max,
         Sum(executions_per_sec_perc95)     executions_per_sec_perc95,
         Sum(executions_per_sec_max)        executions_per_sec_max,
         Sum(io_mbytes_per_sec_perc95)      io_mbytes_per_sec_perc95,
         Sum(io_mbytes_per_sec_max)         io_mbytes_per_sec_max,
         Sum(io_req_per_sec_perc95)         io_req_per_sec_perc95,
         Sum(io_req_per_sec_max)            io_req_per_sec_max,
         Sum(logons_per_sec_perc95)         logons_per_sec_perc95,
         Sum(logons_per_sec_max)            logons_per_sec_max,
         Sum(phy_rds_per_sec_perc95)        phy_rds_per_sec_perc95,
         Sum(phy_rds_per_sec_max)           phy_rds_per_sec_max,
         Sum(phy_wts_per_sec_perc95)        phy_wts_per_sec_perc95,
         Sum(phy_wts_per_sec_max)           phy_wts_per_sec_max,
         Sum(redo_per_sec_perc95)           redo_per_sec_perc95,
         Sum(redo_per_sec_max)              redo_per_sec_max,
         Sum(sql_rt_per_sec_perc95)         sql_rt_per_sec_perc95,
         Sum(sql_rt_per_sec_max)            sql_rt_per_sec_max,
         Sum(transac_per_sec_perc95)        transac_per_sec_perc95,
         Sum(transac_per_sec_max)           transac_per_sec_max
FROM     (
                SELECT TRIM(pkey)            ckey,
                       TRIM(con_id)          con_id,
                       TRIM(dbid)            dbid,
                       TRIM(instance_number) instance_number,
                       TRIM(hour)            hour,
                       CASE TRIM(metric_name)
                              WHEN 'Average Active Sessions' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS average_active_session_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Average Active Sessions' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS average_active_session_max,
                       CASE TRIM(metric_name)
                              WHEN 'CPU Usage Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS cpu_usage_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'CPU Usage Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS cpu_usage_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Background CPU Usage Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS bkgr_cpu_usage_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Background CPU Usage Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS bkgr_cpu_usage_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Host CPU Usage Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS host_cpu_usage_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Host CPU Usage Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS host_cpu_usage_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Executions Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS executions_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Executions Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS executions_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'I/O Megabytes per Second' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS io_mbytes_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'I/O Megabytes per Second' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS io_mbytes_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'I/O Requests per Second' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS io_req_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'I/O Requests per Second' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS io_req_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Logons Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS logons_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Logons Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS logons_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Physical Reads Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS phy_rds_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Physical Reads Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS phy_rds_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Physical Writes Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS phy_wts_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Physical Writes Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS phy_wts_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'Redo Generated Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS redo_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'Redo Generated Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS redo_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'SQL Service Response Time' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS sql_rt_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'SQL Service Response Time' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS sql_rt_per_sec_max,
                       CASE TRIM(metric_name)
                              WHEN 'User Transaction Per Sec' THEN Cast(TRIM(a.perc95) AS INT64)
                       END AS transac_per_sec_perc95,
                       CASE TRIM(metric_name)
                              WHEN 'User Transaction Per Sec' THEN Cast(TRIM(a.perc100) AS INT64)
                       END AS transac_per_sec_max
                FROM   ${dataset}.awrhistsysmetrichist a )
GROUP BY ckey,
         con_id,
         dbid,
         instance_number,
         hour;
