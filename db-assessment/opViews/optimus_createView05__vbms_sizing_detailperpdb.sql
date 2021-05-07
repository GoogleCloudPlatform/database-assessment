select a.ckey, b.db_name, b.dbversion ,a.con_id, a.dbid, a.instance_number, e.hostname, a.hour, 
       c.num_cpu_cores source_num_cpu_cores,
       c.host_cpu_utilization_perc source_host_cpu_utilization_perc,
       round((a.cpu_usage_per_sec_perc95+a.bkgr_cpu_usage_per_sec_perc95) / round(a.host_cpu_usage_per_sec_perc95 / c.host_cpu_utilization_perc,1),0) source_db_cpu_utilization_perc,
       round(b.db_size_allocated_gb/1024,1) source_db_size_allocated_tb, 
       d.db_total_memory_gb source_database_memory_gb,
       a.io_req_per_sec_perc95 source_io_rep_per_sec,
       round((c.num_cpu_cores/100)*c.host_cpu_utilization_perc*.8,0) bms_host_machine_cores,
       round((c.num_cpu_cores/100)*(round((a.cpu_usage_per_sec_perc95+a.bkgr_cpu_usage_per_sec_perc95) / round(a.host_cpu_usage_per_sec_perc95 / c.host_cpu_utilization_perc,1),0))*.8,0) bms_database_cores,
       d.db_total_memory_gb bms_database_memory_gb,
       round((a.io_req_per_sec_perc95*1.2)/6000,0) bms_db_tb_disk_for_iops,
       round(a.io_req_per_sec_perc95/6000,0)*60 bms_est_monthly_storage_bill
from `MYDATASET.vsysmetric_hist` a
inner join `MYDATASET.vdbsummary` b
on a.ckey = b.ckey 
inner join `MYDATASET.vosstat_metrics` c
on a.ckey = c.ckey and a.dbid = c.dbid and a.instance_number = c.instance_number and a.hour = c.hour
inner join `MYDATASET.vdbmemory_usageperpdb` d
on a.ckey = d.ckey and a.instance_number = d.inst_id and a.con_id = d.con_id
inner join `MYDATASET.vinstsummary` e
on a.ckey = e.ckey and a.instance_number = e.inst_id;
