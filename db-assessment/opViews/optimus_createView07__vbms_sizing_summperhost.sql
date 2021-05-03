select a.hostname, 
        sum(bms_host_machine_cores) bms_host_machine_cores,
        sum(bms_database_cores) bms_database_cores,
        sum(bms_database_memory_gb) bms_database_memory_gb,
        sum(bms_db_tb_disk_for_iops) bms_db_tb_disk_for_iops,
        sum(bms_est_monthly_storage_bill) bms_est_monthly_storage_bill
from `MYDATASET.vbms_sizing_summperpdb` a
group by a.hostname;
