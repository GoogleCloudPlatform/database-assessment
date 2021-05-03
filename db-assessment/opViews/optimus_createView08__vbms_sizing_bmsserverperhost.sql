with bms_machine_sizing_by_hostname as (
select a.hostname,
      cast(b.cores as int64) - a.bms_host_machine_cores bms_host_machine_cores_left,
      b.machine_size bms_machine_offer, b.cores bms_machine_offer_cores, b.processor bms_offer_processor, b.est_price bms_offer_est_price,
      round((a.bms_host_machine_cores) / cast(b.cores as int64) * 100,0) bms_est_cpu_usage_peak,
      min(cast(b.cores as int64) - a.bms_host_machine_cores) over(partition by a.hostname) as min_bms_machine,
      a.bms_database_memory_gb,
      a.bms_db_tb_disk_for_iops,
      a.bms_est_monthly_storage_bill
from `MYDATASET.vbms_sizing_summperhost` a
cross join `MYDATASET.vconfig_machinesizes` b
where ((cast(b.cores as int64) - a.bms_host_machine_cores) / cast(b.cores as int64) * 100) > 30
order by (cast(b.cores as int64) - a.bms_host_machine_cores) )
select a.hostname,
       a.bms_machine_offer, a.bms_machine_offer_cores, a.bms_offer_processor, a.bms_offer_est_price, a.bms_est_cpu_usage_peak,
      a.bms_database_memory_gb,
      a.bms_db_tb_disk_for_iops,
      a.bms_est_monthly_storage_bill
from bms_machine_sizing_by_hostname a
where a.bms_host_machine_cores_left = min_bms_machine;
