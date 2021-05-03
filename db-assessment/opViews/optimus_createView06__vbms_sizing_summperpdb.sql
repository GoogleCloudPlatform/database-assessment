select a.ckey, a.db_name, a.dbversion, a.dbid, a.instance_number, a.hostname, a.con_id, 
        max(bms_host_machine_cores) bms_host_machine_cores, max(bms_database_cores) bms_database_cores,
        max(bms_database_memory_gb) bms_database_memory_gb, max(bms_db_tb_disk_for_iops) bms_db_tb_disk_for_iops,
        max(bms_est_monthly_storage_bill) bms_est_monthly_storage_bill
from `MYDATASET.vbms_sizing_detailperpdb` a
group by a.ckey, a.db_name, a.dbversion, a.dbid, a.instance_number, a.hostname, a.con_id;
