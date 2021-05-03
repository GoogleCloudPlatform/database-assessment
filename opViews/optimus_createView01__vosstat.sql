select trim(a.pkey) ckey, trim(a.con_id) con_id, trim(a.dbid) dbid, trim(a.instance_number) instance_number, trim(a.hour) hour, trim(a.hour_total_secs) hour_total_secs,
        sum(num_cpus) num_cpus, sum(num_cpu_cores) num_cpu_cores, sum(num_cpu_sockets) num_cpu_sockets,
        sum(physical_memory_bytes) physical_memory_bytes, sum(free_memory_bytes) free_memory_bytes,
        sum(busy_time) busy_time, sum(idle_time) idle_time, sum(sys_time) sys_time,
        sum(vm_in_bytes) vm_in_bytes, sum(vm_out_bytes) vm_out_bytes, sum(load) load
from (
select a.pkey, a.con_id, a.dbid, a.instance_number, a.hour, a.hour_total_secs,
    case trim(stat_name)
        when 'NUM_CPUS' then cast(trim(a.median_value) as int64)
    end as num_cpus,
    case trim(stat_name)
        when 'NUM_CPU_CORES' then cast(trim(a.median_value) as int64)
    end as num_cpu_cores,
    case trim(stat_name)
        when 'NUM_CPU_SOCKETS' then cast(trim(a.median_value) as int64)
    end as num_cpu_sockets,
    case trim(stat_name)
        when 'PHYSICAL_MEMORY_BYTES' then cast(trim(a.median_value) as int64)
    end as physical_memory_bytes,
    case trim(stat_name)
        when 'FREE_MEMORY_BYTES' then cast(trim(a.median_value) as int64)
    end as free_memory_bytes,
    case trim(stat_name)
        when 'BUSY_TIME' then cast(trim(a.median_value) as int64)
    end as busy_time,
    case trim(stat_name)
        when 'IDLE_TIME' then cast(trim(a.median_value) as int64)
    end as idle_time,
    case trim(stat_name)
        when 'SYS_TIME' then cast(trim(a.median_value) as int64)
    end as sys_time,
    case trim(stat_name)
        when 'VM_IN_BYTES' then cast(trim(a.median_value) as int64)
    end as vm_in_bytes,
    case trim(stat_name)
        when 'VM_OUT_BYTES' then cast(trim(a.median_value) as int64)
    end as vm_out_bytes,
    case trim(stat_name)
        when 'LOAD' then cast(trim(a.median_value) as int64)
    end as load,
from `MYDATASET.awrhistosstat` a
--where trim(a.stat_name) in ('FREE_MEMORY_BYTES','PHYSICAL_MEMORY_BYTES','BUSY_TIME','IDLE_TIME','SYS_TIME','VM_IN_BYTES','VM_OUT_BYTES','LOAD')
) a
group by trim(a.pkey), trim(a.con_id), trim(a.dbid), trim(a.instance_number), trim(a.hour), trim(a.hour_total_secs);
