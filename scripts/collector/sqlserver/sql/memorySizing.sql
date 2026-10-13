/*
-- Author: Tim Chapman
Copyright 2026 Google LLC

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

SET ANSI_NULLS ON;
SET QUOTED_IDENTIFIER ON;
SET NOCOUNT ON;
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET LANGUAGE us_english;

DECLARE @PKEY AS VARCHAR(256);
DECLARE @DMA_SOURCE_ID AS VARCHAR(256);
DECLARE @DMA_MANUAL_ID AS VARCHAR(256);

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

WITH DiskUserData AS (
    SELECT
        ISNULL(SUM(CAST(size AS BIGINT) * 8 / 1024), 0) AS user_data_on_disk_mb
    FROM sys.master_files
    WHERE type_desc = 'ROWS' AND database_id > 4
),
BufferPoolUserData AS (
    SELECT
        ISNULL(COUNT_BIG(*) * 8 / 1024, 0) AS buffer_pool_user_data_mb
    FROM sys.dm_os_buffer_descriptors
    WHERE database_id > 4
),
RingBufferPressure AS (
    SELECT
        COUNT(*) AS total_pressure_events,
        ISNULL(SUM(CASE WHEN CAST(r.record AS XML).value('(//Record/ResourceMonitor/IndicatorsProcess)[1]', 'INT') = 1 THEN 1 ELSE 0 END), 0) AS internal_sql_pressure_events,
        ISNULL(SUM(CASE WHEN CAST(r.record AS XML).value('(//Record/ResourceMonitor/IndicatorsSystem)[1]', 'INT') = 1 THEN 1 ELSE 0 END), 0) AS external_os_pressure_events
    FROM sys.dm_os_ring_buffers r
    WHERE r.ring_buffer_type = 'RING_BUFFER_RESOURCE_MONITOR'
)
SELECT
    '"' + @PKEY + '"' AS PKEY,
    '"' + CONVERT(NVARCHAR(30), sm.total_physical_memory_kb / 1024) + '"' AS host_ram_mb,
    '"' + CONVERT(NVARCHAR(30), sm.available_physical_memory_kb / 1024) + '"' AS available_host_ram_mb,
    '"' + CONVERT(NVARCHAR(30), cfg_max.value_in_use) + '"' AS max_server_memory_mb,
    '"' + CONVERT(NVARCHAR(30), cfg_min.value_in_use) + '"' AS min_server_memory_mb,
    '"' + CONVERT(NVARCHAR(30), pm.physical_memory_in_use_kb / 1024) + '"' AS sql_working_set_mb,
    '"' + CASE WHEN pm.locked_page_allocations_kb > 0 THEN 'LOCK_PAGES' ELSE 'CONVENTIONAL' END + '"' AS memory_model,
    '"' + CONVERT(NVARCHAR(30), d.user_data_on_disk_mb) + '"' AS user_data_on_disk_mb,
    '"' + CONVERT(NVARCHAR(30), b.buffer_pool_user_data_mb) + '"' AS buffer_pool_user_data_mb,
    '"' + CONVERT(NVARCHAR(20), rb.total_pressure_events) + '"' AS lifetime_pressure_events,
    '"' + CONVERT(NVARCHAR(20), rb.internal_sql_pressure_events) + '"' AS internal_sql_pressure_events,
    '"' + CONVERT(NVARCHAR(20), rb.external_os_pressure_events) + '"' AS external_os_pressure_events,
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
FROM sys.dm_os_sys_memory sm
CROSS JOIN sys.dm_os_process_memory pm
CROSS JOIN (SELECT value_in_use FROM sys.configurations WHERE name = 'max server memory (MB)') cfg_max
CROSS JOIN (SELECT value_in_use FROM sys.configurations WHERE name = 'min server memory (MB)') cfg_min
CROSS JOIN DiskUserData d
CROSS JOIN BufferPoolUserData b
CROSS JOIN RingBufferPressure rb;
