SELECT   TRIM(a.pkey)               ckey,
         TRIM(a.con_id)             con_id,
         TRIM(a.dbid)               dbid,
         TRIM(a.instance_number)    instance_number,
         TRIM(a.hour)               hour,
         TRIM(a.hour_total_secs)    hour_total_secs,
         Sum(num_cpus)              num_cpus,
         Sum(num_cpu_cores)         num_cpu_cores,
         Sum(num_cpu_sockets)       num_cpu_sockets,
         Sum(physical_memory_bytes) physical_memory_bytes,
         Sum(free_memory_bytes)     free_memory_bytes,
         Sum(busy_time)             busy_time,
         Sum(idle_time)             idle_time,
         Sum(sys_time)              sys_time,
         Sum(vm_in_bytes)           vm_in_bytes,
         Sum(vm_out_bytes)          vm_out_bytes,
         Sum(LOAD)                  LOAD
FROM     (
                SELECT a.pkey,
                       a.con_id,
                       a.dbid,
                       a.instance_number,
                       a.hour,
                       a.hour_total_secs,
                       CASE TRIM(stat_name)
                              WHEN 'NUM_CPUS' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS num_cpus,
                       CASE TRIM(stat_name)
                              WHEN 'NUM_CPU_CORES' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS num_cpu_cores,
                       CASE TRIM(stat_name)
                              WHEN 'NUM_CPU_SOCKETS' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS num_cpu_sockets,
                       CASE TRIM(stat_name)
                              WHEN 'PHYSICAL_MEMORY_BYTES' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS physical_memory_bytes,
                       CASE TRIM(stat_name)
                              WHEN 'FREE_MEMORY_BYTES' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS free_memory_bytes,
                       CASE TRIM(stat_name)
                              WHEN 'BUSY_TIME' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS busy_time,
                       CASE TRIM(stat_name)
                              WHEN 'IDLE_TIME' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS idle_time,
                       CASE TRIM(stat_name)
                              WHEN 'SYS_TIME' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS sys_time,
                       CASE TRIM(stat_name)
                              WHEN 'VM_IN_BYTES' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS vm_in_bytes,
                       CASE TRIM(stat_name)
                              WHEN 'VM_OUT_BYTES' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS vm_out_bytes,
                       CASE TRIM(stat_name)
                              WHEN 'LOAD' THEN Cast(TRIM(a.median_value) AS INT64)
                       END AS LOAD,
                FROM   mydataset.awrhistosstat a
         ) a
GROUP BY trim(a.pkey),
         trim(a.con_id),
         trim(a.dbid),
         trim(a.instance_number),
         trim(a.hour),
         trim(a.hour_total_secs);
