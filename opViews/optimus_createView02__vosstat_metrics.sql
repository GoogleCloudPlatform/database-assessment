select  a.ckey, a.con_id, a.dbid, a.instance_number, b.hostname, a.hour,
        a.num_cpus, a.num_cpu_cores, a.num_cpu_sockets,
        round(a.physical_memory_bytes/1024/1024/1024,0) host_mem_gb,
        round(a.free_memory_bytes/a.physical_memory_bytes*100,0) host_free_mem_perc,
        round(busy_time/(idle_time+busy_time)*100,0) host_cpu_utilization_perc,
        round(sys_time/(idle_time+busy_time)*100,0) host_sys_cpu_utilization_perc,
        round(load,0) host_load_avg,
        round((a.vm_in_bytes+a.vm_out_bytes)/a.physical_memory_bytes*100,0) host_swap_bytes_perc
from `MYDATASET.vosstat` a
inner join `MYDATASET.vinstsummary` b
on a.ckey = b.ckey and a.instance_number = b.inst_id;
