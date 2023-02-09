--Script to Monitor SQL Server Memory Usage: System Memory Information
select
      total_physical_memory_kb/1024 AS total_physical_memory_mb,
      available_physical_memory_kb/1024 AS available_physical_memory_mb,
      total_page_file_kb/1024 AS total_page_file_mb,
      available_page_file_kb/1024 AS available_page_file_mb,
      100 - CAST((100 * CAST(available_physical_memory_kb AS DECIMAL(18,3))/CAST(total_physical_memory_kb AS DECIMAL(18,3))) AS DECIMAL(18,2))
      AS 'Percentage_Used',
      system_memory_state_desc
from  sys.dm_os_sys_memory;

--Script to Monitor SQL Server Memory Usage: Top Performance Counters – Memory
-- Get size of SQL Server Page in bytes
DECLARE @pg_size INT, @Instancename varchar(50)
SELECT @pg_size = low from master..spt_values where number = 1 and type = 'E'

-- Extract perfmon counters to a temporary table
IF OBJECT_ID('tempdb..#perfmon_counters') is not null DROP TABLE #perfmon_counters
SELECT * INTO #perfmon_counters FROM sys.dm_os_performance_counters;

-- Get SQL Server instance name as it require for capturing Buffer Cache hit Ratio
SELECT  @Instancename = LEFT([object_name], (CHARINDEX(':',[object_name]))) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Buffer cache hit ratio';


SELECT * FROM (
SELECT  'Total Server Memory (GB)' as Cntr,
        (cntr_value/1048576.0) AS Value 
FROM    #perfmon_counters 
WHERE   counter_name = 'Total Server Memory (KB)'
UNION ALL
SELECT  'Target Server Memory (GB)', 
        (cntr_value/1048576.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Target Server Memory (KB)'
UNION ALL
SELECT  'Connection Memory (MB)', 
        (cntr_value/1024.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Connection Memory (KB)'
UNION ALL
SELECT  'Lock Memory (MB)', 
        (cntr_value/1024.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Lock Memory (KB)'
UNION ALL
SELECT  'SQL Cache Memory (MB)', 
        (cntr_value/1024.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'SQL Cache Memory (KB)'
UNION ALL
SELECT  'Optimizer Memory (MB)', 
        (cntr_value/1024.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Optimizer Memory (KB) '
UNION ALL
SELECT  'Granted Workspace Memory (MB)', 
        (cntr_value/1024.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Granted Workspace Memory (KB) '
UNION ALL
SELECT  'Cursor memory usage (MB)', 
        (cntr_value/1024.0) 
FROM    #perfmon_counters 
WHERE   counter_name = 'Cursor memory usage' and instance_name = '_Total'
UNION ALL
SELECT  'Total pages Size (MB)', 
        (cntr_value*@pg_size)/1048576.0 
FROM    #perfmon_counters 
WHERE   object_name= @Instancename+'Buffer Manager' 
        and counter_name = 'Total pages'
UNION ALL
SELECT  'Database pages (MB)', 
        (cntr_value*@pg_size)/1048576.0 
FROM    #perfmon_counters 
WHERE   object_name = @Instancename+'Buffer Manager' and counter_name = 'Database pages'
UNION ALL
SELECT  'Free pages (MB)', 
        (cntr_value*@pg_size)/1048576.0 
FROM    #perfmon_counters 
WHERE   object_name = @Instancename+'Buffer Manager' 
        and counter_name = 'Free pages'
UNION ALL
SELECT  'Reserved pages (MB)', 
        (cntr_value*@pg_size)/1048576.0 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Buffer Manager' 
        and counter_name = 'Reserved pages'
UNION ALL
SELECT  'Stolen pages (MB)', 
        (cntr_value*@pg_size)/1048576.0 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Buffer Manager' 
        and counter_name = 'Stolen pages'
UNION ALL
SELECT  'Cache Pages (MB)', 
        (cntr_value*@pg_size)/1048576.0 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Plan Cache' 
        and counter_name = 'Cache Pages' and instance_name = '_Total'
UNION ALL
SELECT  'Page Life Expectency in seconds',
        cntr_value 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Buffer Manager' 
        and counter_name = 'Page life expectancy'
UNION ALL
SELECT  'Free list stalls/sec',
        cntr_value 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Buffer Manager' 
        and counter_name = 'Free list stalls/sec'
UNION ALL
SELECT  'Checkpoint pages/sec',
        cntr_value 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Buffer Manager' 
        and counter_name = 'Checkpoint pages/sec'
UNION ALL
SELECT  'Lazy writes/sec',
        cntr_value 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Buffer Manager' 
        and counter_name = 'Lazy writes/sec'
UNION ALL
SELECT  'Memory Grants Pending',
        cntr_value 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Memory Manager' 
        and counter_name = 'Memory Grants Pending'
UNION ALL
SELECT  'Memory Grants Outstanding',
        cntr_value 
FROM    #perfmon_counters 
WHERE   object_name=@Instancename+'Memory Manager' 
        and counter_name = 'Memory Grants Outstanding'
UNION ALL
SELECT  'process_physical_memory_low',
        process_physical_memory_low 
FROM    sys.dm_os_process_memory WITH (NOLOCK)
UNION ALL
SELECT  'process_virtual_memory_low',
        process_virtual_memory_low 
FROM    sys.dm_os_process_memory WITH (NOLOCK)
UNION ALL
SELECT  'Max_Server_Memory (MB)' ,
        [value_in_use] 
FROM    sys.configurations 
WHERE   [name] = 'max server memory (MB)'
UNION ALL
SELECT  'Min_Server_Memory (MB)' ,
        [value_in_use] 
FROM    sys.configurations 
WHERE   [name] = 'min server memory (MB)'
UNION ALL
SELECT  'BufferCacheHitRatio',
        (a.cntr_value * 1.0 / b.cntr_value) * 100.0 
FROM    sys.dm_os_performance_counters a
        JOIN (SELECT cntr_value,OBJECT_NAME FROM sys.dm_os_performance_counters
              WHERE counter_name = 'Buffer cache hit ratio base' AND 
                    OBJECT_NAME = @Instancename+'Buffer Manager') b ON 
                    a.OBJECT_NAME = b.OBJECT_NAME WHERE a.counter_name = 'Buffer cache hit ratio' 
                    AND a.OBJECT_NAME = @Instancename+'Buffer Manager'

) AS D;