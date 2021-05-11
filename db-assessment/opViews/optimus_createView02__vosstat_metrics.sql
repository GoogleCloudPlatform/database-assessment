SELECT a.ckey,
       a.con_id,
       a.dbid,
       a.instance_number,
       b.hostname,
       a.hour,
       a.num_cpus,
       a.num_cpu_cores,
       a.num_cpu_sockets,
       ROUND(a.physical_memory_bytes / 1024 / 1024 / 1024, 0)        host_mem_gb
       ,
       ROUND(a.free_memory_bytes / a.physical_memory_bytes * 100, 0)
       host_free_mem_perc,
       ROUND(busy_time / ( idle_time + busy_time ) * 100, 0)
       host_cpu_utilization_perc,
       ROUND(sys_time / ( idle_time + busy_time ) * 100, 0)
       host_sys_cpu_utilization_perc,
       ROUND(LOAD, 0)
       host_load_avg,
ROUND(( a.vm_in_bytes + a.vm_out_bytes ) / a.physical_memory_bytes * 100, 0)
       host_swap_bytes_perc
FROM   ${dataset}.vosstat a
       INNER JOIN ${dataset}.vinstsummary b
               ON a.ckey = b.ckey
                  AND a.instance_number = b.inst_id; 
