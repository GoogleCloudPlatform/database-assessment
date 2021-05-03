select hostname, hour, source_num_cpu_cores, source_host_cpu_utilization_perc,
        sum(source_db_size_allocated_tb) source_db_size_allocated_tb,
        sum(source_database_memory_gb) source_database_memory_gb,
        sum(source_io_rep_per_sec) source_io_rep_per_sec,
        round((source_num_cpu_cores/100)*source_host_cpu_utilization_perc*.8,0) bms_host_machine_cores,
        sum(bms_database_memory_gb) bms_total_database_memory_gb,
        sum(bms_db_tb_disk_for_iops) bms_total_db_tb_disk_for_iops,
        sum(bms_est_monthly_storage_bill) bms_est_monthly_total_storage_bill
from `MYDATASET.vbms_sizing_detailperpdb`
group by hostname, hour, source_num_cpu_cores, source_host_cpu_utilization_perc;
