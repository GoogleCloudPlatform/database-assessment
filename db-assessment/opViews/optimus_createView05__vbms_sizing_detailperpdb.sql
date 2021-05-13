SELECT a.ckey,
       b.db_name,
       b.dbversion,
       a.con_id,
       a.dbid,
       a.instance_number,
       e.hostname,
       a.hour,
       c.num_cpu_cores                                    source_num_cpu_cores,
       c.host_cpu_utilization_perc
       source_host_cpu_utilization_perc,
       ROUND(( a.cpu_usage_per_sec_perc95
               + a.bkgr_cpu_usage_per_sec_perc95 ) /
             ROUND(a.host_cpu_usage_per_sec_perc95 /
       c.host_cpu_utilization_perc, 1), 0)
       source_db_cpu_utilization_perc,
       ROUND(b.db_size_allocated_gb / 1024, 1)
       source_db_size_allocated_tb,
       d.db_total_memory_gb
       source_database_memory_gb,
       a.io_req_per_sec_perc95                            source_io_rep_per_sec,
       ROUND(( c.num_cpu_cores / 100 ) * c.host_cpu_utilization_perc *. 8, 0)
                                                          bms_host_machine_cores
       ,
       ROUND(( c.num_cpu_cores / 100 ) * (
             ROUND(
                   ( a.cpu_usage_per_sec_perc95
                     + a.bkgr_cpu_usage_per_sec_perc95 )
                   /
                   ROUND(
                   a.host_cpu_usage_per_sec_perc95 /
       c.host_cpu_utilization_perc, 1), 0) ) *. 8, 0)     bms_database_cores,
       d.db_total_memory_gb                               bms_database_memory_gb
       ,
       ROUND(( a.io_req_per_sec_perc95 * 1.2 ) / 6000, 0)
       bms_db_tb_disk_for_iops,
       ROUND(a.io_req_per_sec_perc95 / 6000, 0) * 60
       bms_est_monthly_storage_bill
FROM   ${dataset}.vsysmetric_hist a
       INNER JOIN ${dataset}.vdbsummary b
               ON a.ckey = b.ckey
       INNER JOIN ${dataset}.vosstat_metrics c
               ON a.ckey = c.ckey
                  AND a.dbid = c.dbid
                  AND a.instance_number = c.instance_number
                  AND a.hour = c.hour
       INNER JOIN ${dataset}.vdbmemory_usageperpdb d
               ON a.ckey = d.ckey
                  AND a.instance_number = d.inst_id
                  AND a.con_id = d.con_id
       INNER JOIN ${dataset}.vinstsummary e
               ON a.ckey = e.ckey
                  AND a.instance_number = e.inst_id; 
