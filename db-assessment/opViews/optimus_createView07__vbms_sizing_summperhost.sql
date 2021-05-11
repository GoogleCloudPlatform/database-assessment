SELECT a.hostname,
       SUM(bms_host_machine_cores)       bms_host_machine_cores,
       SUM(bms_database_cores)           bms_database_cores,
       SUM(bms_database_memory_gb)       bms_database_memory_gb,
       SUM(bms_db_tb_disk_for_iops)      bms_db_tb_disk_for_iops,
       SUM(bms_est_monthly_storage_bill) bms_est_monthly_storage_bill
FROM   mydataset.vbms_sizing_summperpdb a
GROUP  BY a.hostname; 
