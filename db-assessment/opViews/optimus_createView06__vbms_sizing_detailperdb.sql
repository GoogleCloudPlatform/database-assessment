select a.ckey, a.db_name, a.dbid, a.dbversion, a.hour, a.source_db_size_allocated_tb, 
        sum(a.source_num_cpu_cores) source_num_cpu_cores,
        sum(a.source_host_cpu_utilization_perc)  source_host_cpu_utilization_perc,
        sum(a.source_db_cpu_utilization_perc) source_db_cpu_utilization_perc,
        sum(a.source_database_memory_gb) source_database_memory_gb,
        sum(a.source_io_rep_per_sec) source_io_rep_per_sec,
        sum(a.bms_host_machine_cores) bms_host_machine_cores,
        sum(a.bms_database_cores) bms_database_cores,
        sum(a.bms_database_memory_gb) bms_database_memory_gb,
        sum(a.bms_db_tb_disk_for_iops) bms_db_tb_disk_for_iops,
        sum(a.bms_est_monthly_storage_bill) bms_est_monthly_storage_bill
from `MYDATASET.vbms_sizing_detailperpdb` a
group by a.ckey, a.db_name, a.dbid, a.dbversion, a.hour, a.source_db_size_allocated_tb;
