/*
Copyright 2023 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

*/

SET NOCOUNT ON;
SET LANGUAGE us_english;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;

DECLARE @PKEY AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

IF OBJECT_ID('tempdb..#serverDmvPerfmon') IS NOT NULL
    DROP TABLE #serverDmvPerfmon;

CREATE TABLE #serverDmvPerfmon (
    COLLECTION_TIME nvarchar(256),
    available_mbytes nvarchar(256),
    physicaldisk_avg_disk_bytes_read nvarchar(256),
    physicaldisk_avg_disk_bytes_write nvarchar(256),
    physicaldisk_avg_disk_bytes_read_sec nvarchar(256),
    physicaldisk_avg_disk_bytes_write_sec nvarchar(256),
    physicaldisk_disk_reads_sec nvarchar(256),
    physicaldisk_disk_writes_sec nvarchar(256),
    processor_idle_time_pct nvarchar(256),
    processor_total_time_pct nvarchar(256),
    processor_frequency nvarchar(256),
    processor_queue_length nvarchar(256),
    buffer_cache_hit_ratio nvarchar(256),
    checkpoint_pages_sec nvarchar(256),
    free_list_stalls_sec nvarchar(256),
    page_life_expectancy nvarchar(256),
    page_lookups_sec nvarchar(256),
    page_reads_sec nvarchar(256),
    page_writes_sec nvarchar(256),
    user_connection_count nvarchar(256),
    memory_grants_pending nvarchar(256),
    target_server_memory_kb nvarchar(256),
    total_server_memory_kb nvarchar(256),
    batch_requests_sec nvarchar(256)
);

BEGIN TRY
BEGIN
exec('
DECLARE @ticksNow bigint, @ticksMs bigint;

-- Calculate ticks to timestamp
SELECT @ticksNow = OSI.cpu_ticks / CONVERT(float, OSI.cpu_ticks/ms_ticks)
      ,@ticksMs = cpu_ticks/ms_ticks
FROM sys.dm_os_sys_info AS OSI;

WITH util AS (
    SELECT
        ''' + @PKEY + ''' AS PKEY,
        RBS.Rc.value(''(./Record/@id)[1]'', ''bigint'') AS RecordID,
        RBS.Rc.value(''(//SystemHealth/SystemIdle)[1]'', ''bigint'') AS SystemIdle, -- SystemIdle on Linux will be 0
        RBS.Rc.value(''(//SystemHealth/ProcessUtilization)[1]'',''bigint'') AS ProcessUtil,
        RBS.Rc.value(''(//SystemHealth/MemoryUtilization)[1]'',''bigint'') AS MemoryUtil,
        RBS.Rc.value(''(//SystemHealth/PageFaults)[1]'', ''bigint'') AS PageFaults,
        RBS.Rc.value(''(//SystemHealth/UserModeTime)[1]'', ''bigint'') AS UserModeTime,
        RBS.Rc.value(''(//SystemHealth/KernelModeTime)[1]'', ''bigint'') AS KernelModeTime,
        RBS.EventStamp
    FROM (
            SELECT ORB.[timestamp] AS EventStamp,
                CONVERT(XML, ORB.record) AS Rc
            FROM sys.dm_os_ring_buffers AS ORB
            WHERE ORB.ring_buffer_type = ''RING_BUFFER_SCHEDULER_MONITOR''
        ) AS RBS
),
sample_iops AS (
    SELECT
        ''' + @PKEY + ''' AS PKEY,
        --mf.physical_name AS DISK_Drive,
        SUM(CONVERT(bigint,sample_ms)) as sample_ms,
        SUM(CONVERT(bigint,num_of_reads)) AS DISK_num_of_reads,
        SUM(CONVERT(bigint,io_stall_read_ms)) AS DISK_io_stall_read_ms,
        SUM(CONVERT(bigint,num_of_writes)) AS DISK_num_of_writes,
        SUM(CONVERT(bigint,io_stall_write_ms)) AS DISK_io_stall_write_ms,
        SUM(CONVERT(bigint,num_of_bytes_read)) AS DISK_num_of_bytes_read,
        SUM(CONVERT(bigint,num_of_bytes_written)) AS DISK_num_of_bytes_written,
        SUM(CONVERT(bigint,io_stall)) AS io_stall
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
        INNER JOIN sys.database_files AS mf WITH (NOLOCK) ON vfs.database_id = (select db_id(DB_NAME()))
        AND vfs.file_id = mf.file_id
    --GROUP BY mf.physical_name
),
dmv_perfmon_counter_data as (
    SELECT
        CONVERT(NVARCHAR,(ROUND((CONVERT(FLOAT,[Buffer cache hit ratio]) * 1.0 / CONVERT(FLOAT,[Buffer cache hit ratio base])) * 100.0,0))) as buffer_cache_hit_ratio,
        CONVERT(NVARCHAR,[Checkpoint pages/sec]) as checkpoint_pages_sec,
        CONVERT(NVARCHAR,[Free list stalls/sec]) as free_list_stalls_sec,
        CONVERT(NVARCHAR,[Page life expectancy]) as page_life_expectancy,
        CONVERT(NVARCHAR,[Page lookups/sec]) as page_lookups_sec,
        CONVERT(NVARCHAR,[Page reads/sec]) as page_reads_sec,
        CONVERT(NVARCHAR,[Page writes/sec]) as page_writes_sec,
        CONVERT(NVARCHAR,[User Connections]) as user_connections,
        CONVERT(NVARCHAR,[Memory Grants Pending]) as memory_grants_pending,
        CONVERT(NVARCHAR,[Target Server Memory (KB)]) as target_server_memory_kb,
        CONVERT(NVARCHAR,[Total Server Memory (KB)]) as total_server_memory_kb,
        CONVERT(NVARCHAR,[Batch Requests/sec]) as batch_requests_sec
    FROM
        (
            SELECT counter_name, cntr_value
            FROM sys.dm_os_performance_counters
            WHERE
                (object_name = ''SQLServer:Buffer Manager''
                AND counter_name IN (''Buffer cache hit ratio'',''Checkpoint pages/sec'',''Free list stalls/sec'',''Page life expectancy'',''Page lookups/sec'',''Page reads/sec'',''Page writes/sec'',''Buffer cache hit ratio base''))
                    OR (object_name = ''SQLServer:General Statistics''
                AND counter_name IN (''User Connections''))
                    OR (object_name = ''SQLServer:Memory Manager''
                AND counter_name IN (''Memory Grants Pending'',''Target Server Memory (KB)'',''Total Server Memory (KB)''))
                    OR (object_name = ''SQLServer:SQL Statistics''
                AND counter_name IN (''Batch Requests/sec''))
        ) AS SourceTable
        PIVOT
        (
            AVG(cntr_value)
            FOR counter_name IN (
                [Buffer cache hit ratio],
                [Buffer cache hit ratio base],
                [Checkpoint pages/sec],
                [Free list stalls/sec],
                [Page life expectancy],
                [Page lookups/sec],
                [Page reads/sec],
                [Page writes/sec],
                [User Connections],
                [Memory Grants Pending],
                [Target Server Memory (KB)],
                [Total Server Memory (KB)],
                [Batch Requests/sec])
        ) AS PivotTable
    )
    INSERT INTO #serverDmvPerfmon
    SELECT
        CONVERT(VARCHAR(23),CONVERT(datetime2(3),DATEADD(ms, -1 * (@ticksNow - UT.EventStamp), GETDATE())),121) AS COLLECTION_TIME,
        NULL AS AVAILABLE_MBYTES,
        CASE
            WHEN DISK_num_of_reads = 0 THEN ''0''
            ELSE CONVERT(NVARCHAR,(DISK_num_of_bytes_read / DISK_num_of_reads))
        END AS [PHYSICALDISK_AVG_DISK_BYTES_READ],
        CASE
            WHEN SI.DISK_io_stall_write_ms = 0 THEN ''0''
            ELSE CONVERT(NVARCHAR,(SI.DISK_num_of_bytes_written / SI.DISK_num_of_writes))
        END AS [PHYSICALDISK_AVG_DISK_BYTES_WRITE],
        CASE
            WHEN SI.DISK_num_of_reads = 0 THEN ''0''
            ELSE CONVERT(NVARCHAR,(SI.DISK_io_stall_read_ms / SI.DISK_num_of_reads))
        END AS [PHYSICALDISK_AVG_DISK_BYTES_READ_SEC],
        CASE
            WHEN SI.DISK_io_stall_write_ms = 0 THEN ''0''
            ELSE CONVERT(NVARCHAR,(SI.DISK_io_stall_write_ms / SI.DISK_num_of_writes))
        END AS [PHYSICALDISK_AVG_DISK_BYTES_WRITE_SEC],
        CASE
            WHEN (SI.DISK_num_of_reads = 0) THEN ''0''
            ELSE CONVERT(NVARCHAR,((SI.DISK_num_of_reads /(SI.sample_ms / 1000))))
        END AS [PHYSICALDISK_DISK_READS_SEC],
        CASE
            WHEN (SI.DISK_num_of_writes = 0) THEN ''0''
            ELSE CONVERT(NVARCHAR,((SI.DISK_num_of_writes /(SI.sample_ms / 1000))))
        END AS [PHYSICALDISK_DISK_WRITES_SEC],
        CASE
            WHEN UT.SystemIdle = 0 THEN CONVERT(NVARCHAR,(100 - UT.ProcessUtil))
            ELSE CONVERT(NVARCHAR,UT.SystemIdle)
        END AS PROCESSOR_IDLE_TIME_PCT,
        CONVERT(NVARCHAR,UT.ProcessUtil) AS PROCESSOR_TOTAL_TIME_PCT,
        NULL AS PROCESSOR_FREQUENCY,
        NULL AS PROCESSOR_QUEUE_LENGTH,
        (SELECT buffer_cache_hit_ratio FROM dmv_perfmon_counter_data) AS BUFFER_CACHE_HIT_RATIO,
        (SELECT checkpoint_pages_sec FROM dmv_perfmon_counter_data) AS CHECKPOINT_PAGES_SEC,
        CASE
            WHEN (SI.DISK_num_of_reads = 0 AND SI.DISK_num_of_writes = 0) THEN ''0''
            ELSE CONVERT(NVARCHAR,(SI.io_stall /(SI.DISK_num_of_reads + SI.DISK_num_of_writes)))
        END AS [FREE_LIST_STALLS_SEC],
        (SELECT page_life_expectancy FROM dmv_perfmon_counter_data) AS PAGE_LIFE_EXPECTANCY,
        (SELECT page_lookups_sec FROM dmv_perfmon_counter_data) AS PAGE_LOOKUPS_SEC,
        (SELECT page_reads_sec FROM dmv_perfmon_counter_data) AS PAGE_READS_SEC,
        (SELECT page_writes_sec FROM dmv_perfmon_counter_data) AS PAGE_WRITES_SEC,
        (SELECT user_connections FROM dmv_perfmon_counter_data) AS USER_CONNECTION_COUNT,
        (SELECT memory_grants_pending FROM dmv_perfmon_counter_data) AS MEMORY_GRANTS_PENDING,
        (SELECT target_server_memory_kb FROM dmv_perfmon_counter_data) AS TARGET_SERVER_MEMORY_KB,
        (SELECT total_server_memory_kb FROM dmv_perfmon_counter_data) AS TOTAL_SERVER_MEMORY_KB,
        (SELECT batch_requests_sec FROM dmv_perfmon_counter_data) AS BATCH_REQUESTS_SEC
    FROM util AS UT
        JOIN sample_iops SI ON (UT.PKEY = SI.PKEY)
    ORDER BY 1 DESC
');

SELECT
    @PKEY as PKEY,
    COLLECTION_TIME,
    AVAILABLE_MBYTES,
    PHYSICALDISK_AVG_DISK_BYTES_READ,
    PHYSICALDISK_AVG_DISK_BYTES_WRITE,
    PHYSICALDISK_AVG_DISK_BYTES_READ_SEC,
    PHYSICALDISK_AVG_DISK_BYTES_WRITE_SEC,
    PHYSICALDISK_DISK_READS_SEC,
    PHYSICALDISK_DISK_WRITES_SEC,
    PROCESSOR_IDLE_TIME_PCT,
    PROCESSOR_TOTAL_TIME_PCT,
    PROCESSOR_FREQUENCY,
    PROCESSOR_QUEUE_LENGTH,
    BUFFER_CACHE_HIT_RATIO,
    CHECKPOINT_PAGES_SEC,
    FREE_LIST_STALLS_SEC,
    PAGE_LIFE_EXPECTANCY,
    PAGE_LOOKUPS_SEC,
    PAGE_READS_SEC,
    PAGE_WRITES_SEC,
    USER_CONNECTION_COUNT,
    MEMORY_GRANTS_PENDING,
    TARGET_SERVER_MEMORY_KB,
    TOTAL_SERVER_MEMORY_KB,
    BATCH_REQUESTS_SEC,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #serverDmvPerfmon;
END;
END TRY
BEGIN CATCH
BEGIN
	IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
		WAITFOR DELAY '00:00:00'
	ELSE
      SELECT
         host_name() as host_name,
         db_name() as database_name,
         'dmvPerfmon' as module_name,
         SUBSTRING(CONVERT(nvarchar,ERROR_NUMBER()),1,254) as error_number,
         SUBSTRING(CONVERT(nvarchar,ERROR_SEVERITY()),1,254) as error_severity,
         SUBSTRING(CONVERT(nvarchar,ERROR_STATE()),1,254) as error_state,
         ERROR_MESSAGE() as error_message;
END
END CATCH

IF OBJECT_ID('tempdb..#serverDmvPerfmon') IS NOT NULL
    DROP TABLE #serverDmvPerfmon;
