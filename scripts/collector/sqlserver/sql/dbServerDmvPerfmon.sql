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

DECLARE @PKEY AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

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

BEGIN
DECLARE @ticksNow bigint, @ticksMs bigint;

-- Calculate ticks to timestamp
SELECT @ticksNow = OSI.cpu_ticks / CONVERT(float, OSI.cpu_ticks/ms_ticks)
      ,@ticksMs = cpu_ticks/ms_ticks
FROM sys.dm_os_sys_info AS OSI;

WITH util AS (
    SELECT 
        RBS.Rc.value('(./Record/@id)[1]', 'bigint') AS RecordID,
        RBS.Rc.value('(//SystemHealth/SystemIdle)[1]', 'bigint') AS SystemIdle, -- SystemIdle on Linux will be 0
        RBS.Rc.value('(//SystemHealth/ProcessUtilization)[1]','bigint') AS ProcessUtil,
        RBS.Rc.value('(//SystemHealth/MemoryUtilization)[1]','bigint') AS MemoryUtil,
        RBS.Rc.value('(//SystemHealth/PageFaults)[1]', 'bigint') AS PageFaults,
        RBS.Rc.value('(//SystemHealth/UserModeTime)[1]', 'bigint') AS UserModeTime,
        RBS.Rc.value('(//SystemHealth/KernelModeTime)[1]', 'bigint') AS KernelModeTime,
        RBS.EventStamp
    FROM (
            SELECT ORB.[timestamp] AS EventStamp,
                CONVERT(XML, ORB.record) AS Rc
            FROM sys.dm_os_ring_buffers AS ORB
            WHERE ORB.ring_buffer_type = 'RING_BUFFER_SCHEDULER_MONITOR'
        ) AS RBS
),
sample_iops AS (
    SELECT mf.physical_name AS DISK_Drive,
        SUM(sample_ms) as sample_ms,
        SUM(num_of_reads) AS DISK_num_of_reads,
        SUM(io_stall_read_ms) AS DISK_io_stall_read_ms,
        SUM(num_of_writes) AS DISK_num_of_writes,
        SUM(io_stall_write_ms) AS DISK_io_stall_write_ms,
        SUM(num_of_bytes_read) AS DISK_num_of_bytes_read,
        SUM(num_of_bytes_written) AS DISK_num_of_bytes_written,
        SUM(io_stall) AS io_stall
    FROM sys.dm_io_virtual_file_stats(NULL, NULL) AS vfs
        INNER JOIN sys.master_files AS mf WITH (NOLOCK) ON vfs.database_id = mf.database_id
        AND vfs.file_id = mf.file_id
    GROUP BY mf.physical_name
)
INSERT INTO #serverDmvPerfmon
SELECT 
    CONVERT(VARCHAR(23),CONVERT(datetime2(3),DATEADD(ms, -1 * (@ticksNow - UT.EventStamp), GETDATE())),121) AS COLLECTION_TIME,
    NULL AS AVAILABLE_MBYTES,
    CASE
        WHEN DISK_num_of_reads = 0 THEN '0'
        ELSE CONVERT(NVARCHAR,(DISK_num_of_bytes_read / DISK_num_of_reads))
    END AS [PHYSICALDISK_AVG_DISK_BYTES_READ],
    CASE
        WHEN SI.DISK_io_stall_write_ms = 0 THEN '0'
        ELSE CONVERT(NVARCHAR,(SI.DISK_num_of_bytes_written / SI.DISK_num_of_writes))
    END AS [PHYSICALDISK_AVG_DISK_BYTES_WRITE],
    CASE
        WHEN SI.DISK_num_of_reads = 0 THEN '0'
        ELSE CONVERT(NVARCHAR,(SI.DISK_io_stall_read_ms / SI.DISK_num_of_reads))
    END AS [PHYSICALDISK_AVG_DISK_BYTES_READ_SEC],
    CASE
        WHEN SI.DISK_io_stall_write_ms = 0 THEN '0'
        ELSE CONVERT(NVARCHAR,(SI.DISK_io_stall_write_ms / SI.DISK_num_of_writes))
    END AS [PHYSICALDISK_AVG_DISK_BYTES_WRITE_SEC],
    CASE
        WHEN (SI.DISK_num_of_reads = 0) THEN '0'
        ELSE CONVERT(NVARCHAR,((SI.DISK_num_of_reads /(SI.sample_ms / 1000))))
    END AS [PHYSICALDISK_DISK_READS_SEC],
    CASE
        WHEN (SI.DISK_num_of_writes = 0) THEN '0'
        ELSE CONVERT(NVARCHAR,((SI.DISK_num_of_writes /(SI.sample_ms / 1000))))
    END AS [PHYSICALDISK_DISK_WRITES_SEC],
    CASE
        WHEN UT.SystemIdle = 0 THEN CONVERT(NVARCHAR,(100 - UT.ProcessUtil))
        ELSE CONVERT(NVARCHAR,UT.SystemIdle)
    END AS PROCESSOR_IDLE_TIME_PCT,
    CONVERT(NVARCHAR,UT.ProcessUtil) AS PROCESSOR_TOTAL_TIME_PCT,
    NULL AS PROCESSOR_FREQUENCY,
    NULL AS PROCESSOR_QUEUE_LENGTH,
    NULL AS BUFFER_CACHE_HIT_RATIO,
    NULL AS CHECKPOINT_PAGES_SEC,
    CASE
        WHEN (SI.DISK_num_of_reads = 0 AND SI.DISK_num_of_writes = 0) THEN '0'
        ELSE CONVERT(NVARCHAR,(SI.io_stall /(SI.DISK_num_of_reads + SI.DISK_num_of_writes)))
    END AS [FREE_LIST_STALLS_SEC],
    NULL AS PAGE_LIFE_EXPECTANCY,
    NULL AS PAGE_LOOKUPS_SEC,
    NULL AS PAGE_READS_SEC,
    NULL AS PAGE_WRITES_SEC,
    NULL AS USER_CONNECTION_COUNT,
    NULL AS MEMORY_GRANTS_PENDING,
    NULL AS TARGET_SERVER_MEMORY_KB,
    NULL AS TOTAL_SERVER_MEMORY_KB,
    NULL AS BATCH_REQUESTS_SEC
FROM util AS UT
    CROSS JOIN sample_iops SI
ORDER BY 2 DESC;
END

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

IF OBJECT_ID('tempdb..#serverDmvPerfmon') IS NOT NULL  
    DROP TABLE #serverDmvPerfmon;