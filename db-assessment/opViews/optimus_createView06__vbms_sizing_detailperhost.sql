SELECT hostname,
       hour,
       source_num_cpu_cores,
       source_host_cpu_utilization_perc,
       SUM(source_db_size_allocated_tb)  source_db_size_allocated_tb,
       SUM(source_database_memory_gb)    source_database_memory_gb,
       SUM(source_io_rep_per_sec)        source_io_rep_per_sec,
       ROUND(( source_num_cpu_cores / 100 ) * source_host_cpu_utilization_perc
             *. 8, 0)
                                         bms_host_machine_cores,
       SUM(bms_database_memory_gb)       bms_total_database_memory_gb,
       SUM(bms_db_tb_disk_for_iops)      bms_total_db_tb_disk_for_iops,
       SUM(bms_est_monthly_storage_bill) bms_est_monthly_total_storage_bill
FROM   ${dataset}.vbms_sizing_detailperpdb
GROUP  BY hostname,
          hour,
          source_num_cpu_cores,
          source_host_cpu_utilization_perc; 
