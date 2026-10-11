/*
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
SET LANGUAGE us_english;

DECLARE @PKEY AS VARCHAR(256)
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF OBJECT_ID('tempdb..#RBSM') IS NOT NULL
    DROP TABLE #RBSM;

SELECT
    '"' + @PKEY + '"' AS PKEY,
    '"' + ISNULL(CONVERT(NVARCHAR(30), CAST(CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'datetime') AS datetime), 126), N'') + '"' AS [timestamp],
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(/event/data[@name="process_utilization"]/value)[1]', 'int')), N'') + '"' AS process_utilization,
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(/event/data[@name="system_idle"]/value)[1]', 'int')), N'') + '"' AS system_idle,
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
INTO #RBSM
FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
WHERE object_name = 'scheduler_monitor_system_health_ring_buffer_recorded'
AND CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'datetime2') >= DATEADD(day, -7, GETDATE());

SELECT
    PKEY,
    [timestamp],
    process_utilization,
    system_idle,
    dma_source_id,
    dma_manual_id
FROM #RBSM
ORDER BY [timestamp] DESC;

IF OBJECT_ID('tempdb..#RBSM') IS NOT NULL
    DROP TABLE #RBSM;
