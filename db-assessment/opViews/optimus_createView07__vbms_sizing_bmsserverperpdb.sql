with bms_machine_sizing_by_pdb as (
select a.ckey, a.db_name, a.dbversion, a.dbid, a.instance_number, a.con_id,
      cast(b.cores as int64) - a.bms_host_machine_cores bms_host_machine_cores_left,
      b.machine_size bms_machine_offer, b.cores bms_machine_offer_cores, b.processor bms_offer_processor, b.est_price bms_offer_est_price,
      round((a.bms_host_machine_cores) / cast(b.cores as int64) * 100,0) bms_est_cpu_usage_peak,
      min(cast(b.cores as int64) - a.bms_host_machine_cores) over(partition by a.ckey, a.db_name, a.dbversion, a.dbid, a.instance_number) as min_bms_machine
from `MYDATASET.vbms_sizing_summperpdb` a
cross join `MYDATASET.vconfig_machinesizes` b
where ((cast(b.cores as int64) - a.bms_host_machine_cores) / cast(b.cores as int64) * 100) > 30
order by (cast(b.cores as int64) - a.bms_host_machine_cores) )
select a.ckey, a.db_name, a.dbversion, a.dbid, a.instance_number, a.con_id,
       a.bms_machine_offer, a.bms_machine_offer_cores, a.bms_offer_processor, a.bms_offer_est_price, a.bms_est_cpu_usage_peak
from bms_machine_sizing_by_pdb a
where a.bms_host_machine_cores_left = min_bms_machine;
