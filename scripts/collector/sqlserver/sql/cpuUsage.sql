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
SET LANGUAGE us_english;

DECLARE @PKEY AS VARCHAR(256)
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF OBJECT_ID('tempdb..#RBSM') IS NOT NULL
    DROP TABLE #RBSM;

CREATE TABLE #RBSM (
    PKEY NVARCHAR(512),
    [timestamp] NVARCHAR(100),
    process_utilization NVARCHAR(100),
    system_idle NVARCHAR(100),
    dma_source_id NVARCHAR(512),
    dma_manual_id NVARCHAR(512)
);

BEGIN TRY
    INSERT INTO #RBSM (PKEY, [timestamp], process_utilization, system_idle, dma_source_id, dma_manual_id)
    SELECT
        '"' + @PKEY + '"' AS PKEY,
        '"' + CONVERT(NVARCHAR(30), CAST(x.event_xml.value('(/event/@timestamp)[1]', 'datetime') AS datetime), 126) + '"' AS [timestamp],
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(/event/data[@name="process_utilization"]/value)[1]', 'int')) + '"' AS process_utilization,
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(/event/data[@name="system_idle"]/value)[1]', 'int')) + '"' AS system_idle,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
    FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL) AS f
    CROSS APPLY (SELECT TRY_CAST(f.event_data AS XML) AS event_xml) AS x
    WHERE f.object_name = 'scheduler_monitor_system_health_ring_buffer_recorded'
      AND x.event_xml IS NOT NULL
      AND x.event_xml.value('(/event/@timestamp)[1]', 'datetime2') >= DATEADD(day, -7, GETDATE());
END TRY
BEGIN CATCH
    -- Gracefully return 0 rows on Azure SQL Database or restricted hosts without system_health XEL file access
END CATCH;

SELECT *
FROM #RBSM
ORDER BY timestamp DESC;

IF OBJECT_ID('tempdb..#RBSM') IS NOT NULL
    DROP TABLE #RBSM;
