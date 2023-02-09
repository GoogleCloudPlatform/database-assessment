SET QUOTED_IDENTIFIER ON

DECLARE @ts_now bigint = (SELECT cpu_ticks/(cpu_ticks/ms_ticks) FROM sys.dm_os_sys_info WITH (NOLOCK)); 
SELECT AVG([SQL Server Process CPU Utilization]) as AVG_SQLServer_Process_CPU_Utilization, 
                AVG([System Idle Process]) as AVG_System_Idle_Process, 
                AVG([Other Process CPU Utilization]) as Avg_Other_Process_CPU_Utilization, 
                DATEPART(HOUR,[Event Time]) as hourly  FROM (
SELECT TOP(256) SQLProcessUtilization AS [SQL Server Process CPU Utilization], 
                SystemIdle AS [System Idle Process], 
                100 - SystemIdle - SQLProcessUtilization AS [Other Process CPU Utilization], 
                DATEADD(ms, -1 * (@ts_now - [timestamp]), GETDATE()) AS [Event Time] 
 FROM (SELECT record.value('(./Record/@id)[1]', 'int') AS record_id, 
             record.value('(./Record/SchedulerMonitorEvent/SystemHealth/SystemIdle)[1]', 'int') 
             AS [SystemIdle], 
             record.value('(./Record/SchedulerMonitorEvent/SystemHealth/ProcessUtilization)[1]', 'int') 
             AS [SQLProcessUtilization], [timestamp] 
       FROM (SELECT [timestamp], CONVERT(xml, record) AS [record] 
             FROM sys.dm_os_ring_buffers WITH (NOLOCK)
             WHERE ring_buffer_type = N'RING_BUFFER_SCHEDULER_MONITOR' 
             AND record LIKE N'%<SystemHealth>%') AS x) AS y ) as z
 GROUP BY DATEPART(HOUR,[Event Time]);

