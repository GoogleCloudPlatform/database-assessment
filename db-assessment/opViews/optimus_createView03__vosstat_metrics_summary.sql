select ckey, dbid, con_id, instance_number, max(num_cpus) num_cpus, max(num_cpu_cores) num_cpu_cores, max(num_cpu_sockets) num_cpu_sockets, max(host_cpu_utilization_perc) host_cpu_utilization_perc, 
       max(host_sys_cpu_utilization_perc) host_sys_cpu_utilization_perc, max(host_mem_gb) host_mem_gb, max(host_free_mem_perc) host_free_mem_perc, max(host_load_avg)host_load_avg, max(host_swap_bytes_perc) host_swap_bytes_perc
from `MYDATASET.vosstat_metrics`
group by ckey, dbid, con_id, instance_number;

