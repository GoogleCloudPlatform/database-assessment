select 'BMS Sizing Per Database (All Instances Included)' bms_sizing_description, null hostname, a.db_name, a.dbversion, c.max_source_num_cpu_cores, a.bms_machine_offer, a.bms_machine_offer_cores, a.bms_offer_processor, a.bms_offer_est_price, a.bms_database_memory_gb, a.bms_db_tb_disk_for_iops, a.bms_est_monthly_storage_bill  
from `MYDATASET.vbms_sizing_bmsserverperdb` a
inner join ( select b.db_name, b.dbversion, b.dbid, 
      max(b.source_num_cpu_cores) max_source_num_cpu_cores, 
      max(b.source_db_cpu_utilization_perc) max_source_db_cpu_utilization_perc, 
      max(b.source_host_cpu_utilization_perc) max_source_host_cpu_utilization_perc
from `MYDATASET.vbms_sizing_detailperdb` b
group by b.db_name, b.dbversion, b.dbid ) c
on a.db_name = c.db_name and a.dbversion = c.dbversion and a.dbid = c.dbid
union all  
select 'BMS Sizing Per Host (All Databases Included)', b.hostname, null db_name, null dbversion, d.max_source_num_cpu_cores, b.bms_machine_offer, b.bms_machine_offer_cores, b.bms_offer_processor, b.bms_offer_est_price, b.bms_database_memory_gb, b.bms_db_tb_disk_for_iops, b.bms_est_monthly_storage_bill  
from `MYDATASET.vbms_sizing_bmsserverperhost` b
inner join ( select b.hostname, 
      max(b.source_num_cpu_cores) max_source_num_cpu_cores, 
      max(b.source_host_cpu_utilization_perc) max_source_host_cpu_utilization_perc
from `MYDATASET.vbms_sizing_detailperhost` b
group by b.hostname ) d
on b.hostname = d.hostname;
