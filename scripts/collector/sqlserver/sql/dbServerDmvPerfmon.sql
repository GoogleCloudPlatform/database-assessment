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
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

BEGIN
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
            CONVERT(NVARCHAR(255),(ROUND((CONVERT(FLOAT,[Buffer cache hit ratio]) * 1.0 / CONVERT(FLOAT,[Buffer cache hit ratio base])) * 100.0,0))) as buffer_cache_hit_ratio,
            CONVERT(NVARCHAR(255),[Checkpoint pages/sec]) as checkpoint_pages_sec,
            CONVERT(NVARCHAR(255),[Free list stalls/sec]) as free_list_stalls_sec,
            CONVERT(NVARCHAR(255),[Page life expectancy]) as page_life_expectancy,
            CONVERT(NVARCHAR(255),[Page lookups/sec]) as page_lookups_sec,
            CONVERT(NVARCHAR(255),[Page reads/sec]) as page_reads_sec,
            CONVERT(NVARCHAR(255),[Page writes/sec]) as page_writes_sec,
            CONVERT(NVARCHAR(255),[User Connections]) as user_connections,
            CONVERT(NVARCHAR(255),[Memory Grants Pending]) as memory_grants_pending,
            CONVERT(NVARCHAR(255),[Target Server Memory (KB)]) as target_server_memory_kb,
            CONVERT(NVARCHAR(255),[Total Server Memory (KB)]) as total_server_memory_kb,
            CONVERT(NVARCHAR(255),[Batch Requests/sec]) as batch_requests_sec
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
        SELECT
            ''"' + @PKEY + '"'' AS pkey,
            ''"'' + CONVERT(VARCHAR(23),CONVERT(datetime2(3),DATEADD(ms, -1 * (@ticksNow - UT.EventStamp), GETDATE())),121) + ''"'' AS collection_time,
            ''""'' AS available_mbytes,
            CASE
                WHEN DISK_num_of_reads = 0 THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),(DISK_num_of_bytes_read / DISK_num_of_reads)) + ''"''
            END AS physicaldisk_avg_disk_bytes_read,
            CASE
                WHEN SI.DISK_io_stall_write_ms = 0 THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),(SI.DISK_num_of_bytes_written / SI.DISK_num_of_writes)) + ''"''
            END AS physicaldisk_avg_disk_bytes_write,
            CASE
                WHEN SI.DISK_num_of_reads = 0 THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),(SI.DISK_io_stall_read_ms / SI.DISK_num_of_reads)) + ''"''
            END AS physicaldisk_avg_disk_bytes_read_sec,
            CASE
                WHEN SI.DISK_io_stall_write_ms = 0 THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),(SI.DISK_io_stall_write_ms / SI.DISK_num_of_writes)) + ''"''
            END AS physicaldisk_avg_disk_bytes_write_sec,
            CASE
                WHEN (SI.DISK_num_of_reads = 0) THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),((SI.DISK_num_of_reads /(SI.sample_ms / 1000)))) + ''"''
            END AS physicaldisk_disk_reads_sec,
            CASE
                WHEN (SI.DISK_num_of_writes = 0) THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),((SI.DISK_num_of_writes /(SI.sample_ms / 1000)))) + ''"''
            END AS physicaldisk_disk_writes_sec,
            CASE
                WHEN UT.SystemIdle = 0 THEN ''"'' + CONVERT(NVARCHAR(255),(100 - UT.ProcessUtil)) + ''"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),UT.SystemIdle) + ''"''
            END AS processor_idle_time_pct,
            ''"'' + CONVERT(NVARCHAR(255),UT.ProcessUtil) + ''"'' AS processor_total_time_pct,
            ''""'' AS processor_frequency,
            ''""'' AS processor_queue_length,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), buffer_cache_hit_ratio) FROM dmv_perfmon_counter_data) + ''"'' AS buffer_cache_hit_ratio,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), checkpoint_pages_sec) FROM dmv_perfmon_counter_data) + ''"'' AS checkpoint_pages_sec,
            CASE
                WHEN (SI.DISK_num_of_reads = 0 AND SI.DISK_num_of_writes = 0) THEN ''"0"''
                ELSE ''"'' + CONVERT(NVARCHAR(255),(SI.io_stall /(SI.DISK_num_of_reads + SI.DISK_num_of_writes))) + ''"''
            END AS free_list_stalls_sec,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), page_life_expectancy) FROM dmv_perfmon_counter_data) + ''"'' AS page_life_expectancy,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), page_lookups_sec) FROM dmv_perfmon_counter_data) + ''"'' AS page_lookups_sec,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), page_reads_sec) FROM dmv_perfmon_counter_data) + ''"'' AS page_reads_sec,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), page_writes_sec) FROM dmv_perfmon_counter_data) + ''"'' AS page_writes_sec,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), user_connections) FROM dmv_perfmon_counter_data) + ''"'' AS user_connection_count,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), memory_grants_pending) FROM dmv_perfmon_counter_data) + ''"'' AS memory_grants_pending,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), target_server_memory_kb) FROM dmv_perfmon_counter_data) + ''"'' AS target_server_memory_kb,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), total_server_memory_kb) FROM dmv_perfmon_counter_data) + ''"'' AS total_server_memory_kb,
            ''"'' + (SELECT CONVERT(NVARCHAR(255), batch_requests_sec) FROM dmv_perfmon_counter_data) + ''"'' AS batch_requests_sec,
            ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
            ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
        FROM util AS UT
            JOIN sample_iops SI ON (UT.PKEY = SI.PKEY)
        ORDER BY 1 DESC
    ');
    END
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
            SUBSTRING(CONVERT(NVARCHAR(255),ERROR_NUMBER()),1,254) as error_number,
            SUBSTRING(CONVERT(NVARCHAR(255),ERROR_SEVERITY()),1,254) as error_severity,
            SUBSTRING(CONVERT(NVARCHAR(255),ERROR_STATE()),1,254) as error_state,
            ERROR_MESSAGE() as error_message;
    END
END CATCH
END;
