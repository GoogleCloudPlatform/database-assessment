select ckey, con_id, dbid, instance_number, hour,
       sum(average_active_session_perc95) average_active_session_perc95, sum(average_active_session_max) average_active_session_max,
       sum(cpu_usage_per_sec_perc95) cpu_usage_per_sec_perc95, sum(cpu_usage_per_sec_max) cpu_usage_per_sec_max,
       sum(bkgr_cpu_usage_per_sec_perc95) bkgr_cpu_usage_per_sec_perc95, max(bkgr_cpu_usage_per_sec_max) bkgr_cpu_usage_per_sec_max,
       sum(host_cpu_usage_per_sec_perc95) host_cpu_usage_per_sec_perc95, sum(host_cpu_usage_per_sec_max) host_cpu_usage_per_sec_max,
       sum(executions_per_sec_perc95) executions_per_sec_perc95, sum(executions_per_sec_max) executions_per_sec_max,
       sum(io_mbytes_per_sec_perc95) io_mbytes_per_sec_perc95, sum(io_mbytes_per_sec_max) io_mbytes_per_sec_max,
       sum(io_req_per_sec_perc95) io_req_per_sec_perc95, sum(io_req_per_sec_max) io_req_per_sec_max,
       sum(logons_per_sec_perc95) logons_per_sec_perc95, sum(logons_per_sec_max) logons_per_sec_max,
       sum(phy_rds_per_sec_perc95) phy_rds_per_sec_perc95, sum(phy_rds_per_sec_max) phy_rds_per_sec_max,
       sum(phy_wts_per_sec_perc95) phy_wts_per_sec_perc95, sum(phy_wts_per_sec_max) phy_wts_per_sec_max,
       sum(redo_per_sec_perc95) redo_per_sec_perc95, sum(redo_per_sec_max) redo_per_sec_max,
       sum(sql_rt_per_sec_perc95) sql_rt_per_sec_perc95, sum(sql_rt_per_sec_max) sql_rt_per_sec_max,
       sum(transac_per_sec_perc95) transac_per_sec_perc95, sum(transac_per_sec_max) transac_per_sec_max
from (
SELECT trim(pkey) ckey, trim(con_id) con_id, trim(dbid) dbid, trim(instance_number) instance_number, trim(hour) hour, 
     case trim(metric_name)
        when 'Average Active Sessions' then cast(trim(a.perc95) as int64)
    end as average_active_session_perc95,
     case trim(metric_name)
        when 'Average Active Sessions' then cast(trim(a.perc100) as int64)
    end as average_active_session_max,
    case trim(metric_name)
        when 'CPU Usage Per Sec' then cast(trim(a.perc95) as int64)
    end as cpu_usage_per_sec_perc95,
    case trim(metric_name)
        when 'CPU Usage Per Sec' then cast(trim(a.perc100) as int64)
    end as cpu_usage_per_sec_max,
    case trim(metric_name)
        when 'Background CPU Usage Per Sec' then cast(trim(a.perc95) as int64)
    end as bkgr_cpu_usage_per_sec_perc95,
    case trim(metric_name)
        when 'Background CPU Usage Per Sec' then cast(trim(a.perc100) as int64)
    end as bkgr_cpu_usage_per_sec_max,
    case trim(metric_name)
        when 'Host CPU Usage Per Sec' then cast(trim(a.perc95) as int64)
    end as host_cpu_usage_per_sec_perc95,
    case trim(metric_name)
        when 'Host CPU Usage Per Sec' then cast(trim(a.perc100) as int64)
    end as host_cpu_usage_per_sec_max,
    case trim(metric_name)
        when 'Executions Per Sec' then cast(trim(a.perc95) as int64)
    end as executions_per_sec_perc95,
    case trim(metric_name)
        when 'Executions Per Sec' then cast(trim(a.perc100) as int64)
    end as executions_per_sec_max,
    case trim(metric_name)
        when 'I/O Megabytes per Second' then cast(trim(a.perc95) as int64)
    end as io_mbytes_per_sec_perc95,
    case trim(metric_name)
        when 'I/O Megabytes per Second' then cast(trim(a.perc100) as int64)
    end as io_mbytes_per_sec_max,
    case trim(metric_name)
        when 'I/O Requests per Second' then cast(trim(a.perc95) as int64)
    end as io_req_per_sec_perc95,
    case trim(metric_name)
        when 'I/O Requests per Second' then cast(trim(a.perc100) as int64)
    end as io_req_per_sec_max,
    case trim(metric_name)
        when 'Logons Per Sec' then cast(trim(a.perc95) as int64)
    end as logons_per_sec_perc95,
    case trim(metric_name)
        when 'Logons Per Sec' then cast(trim(a.perc100) as int64)
    end as logons_per_sec_max,
    case trim(metric_name)
        when 'Physical Reads Per Sec' then cast(trim(a.perc95) as int64)
    end as phy_rds_per_sec_perc95,
    case trim(metric_name)
        when 'Physical Reads Per Sec' then cast(trim(a.perc100) as int64)
    end as phy_rds_per_sec_max,
    case trim(metric_name)
        when 'Physical Writes Per Sec' then cast(trim(a.perc95) as int64)
    end as phy_wts_per_sec_perc95,
    case trim(metric_name)
        when 'Physical Writes Per Sec' then cast(trim(a.perc100) as int64)
    end as phy_wts_per_sec_max,
    case trim(metric_name)
        when 'Redo Generated Per Sec' then cast(trim(a.perc95) as int64)
    end as redo_per_sec_perc95,
    case trim(metric_name)
        when 'Redo Generated Per Sec' then cast(trim(a.perc100) as int64)
    end as redo_per_sec_max,
    case trim(metric_name)
        when 'SQL Service Response Time' then cast(trim(a.perc95) as int64)
    end as sql_rt_per_sec_perc95,
    case trim(metric_name)
        when 'SQL Service Response Time' then cast(trim(a.perc100) as int64)
    end as sql_rt_per_sec_max,
    case trim(metric_name)
        when 'User Transaction Per Sec' then cast(trim(a.perc95) as int64)
    end as transac_per_sec_perc95,
    case trim(metric_name)
        when 'User Transaction Per Sec' then cast(trim(a.perc100) as int64)
    end as transac_per_sec_max
FROM `MYDATASET.awrhistsysmetrichist` a
)
group by ckey, con_id, dbid, instance_number, hour;
