SELECT ckey,
       dbid,
       con_id,
       instance_number,
       MAX(num_cpus)                      num_cpus,
       MAX(num_cpu_cores)                 num_cpu_cores,
       MAX(num_cpu_sockets)               num_cpu_sockets,
       MAX(host_cpu_utilization_perc)     host_cpu_utilization_perc,
       MAX(host_sys_cpu_utilization_perc) host_sys_cpu_utilization_perc,
       MAX(host_mem_gb)                   host_mem_gb,
       MAX(host_free_mem_perc)            host_free_mem_perc,
       MAX(host_load_avg)                 host_load_avg,
       MAX(host_swap_bytes_perc)          host_swap_bytes_perc
FROM   mydataset.vosstat_metrics
GROUP  BY ckey,
          dbid,
          con_id,
          instance_number; 
