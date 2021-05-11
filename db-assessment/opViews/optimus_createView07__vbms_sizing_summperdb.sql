SELECT a.ckey,
       a.db_name,
       a.dbversion,
       a.dbid,
       MAX(bms_host_machine_cores)       bms_host_machine_cores,
       MAX(bms_database_cores)           bms_database_cores,
       MAX(bms_database_memory_gb)       bms_database_memory_gb,
       MAX(bms_db_tb_disk_for_iops)      bms_db_tb_disk_for_iops,
       MAX(bms_est_monthly_storage_bill) bms_est_monthly_storage_bill
FROM   mydataset.vbms_sizing_detailperdb a
GROUP  BY a.ckey,
          a.db_name,
          a.dbversion,
          a.dbid; 
