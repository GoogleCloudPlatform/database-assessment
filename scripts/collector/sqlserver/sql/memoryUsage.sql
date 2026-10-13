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

IF OBJECT_ID('tempdb..#MemUsage') IS NOT NULL
    DROP TABLE #MemUsage;

CREATE TABLE #MemUsage (
    PKEY NVARCHAR(512),
    [timestamp] NVARCHAR(100),
    [state] NVARCHAR(100),
    available_physical_memory_mb NVARCHAR(100),
    working_set_mb NVARCHAR(100),
    percent_committed_in_ws NVARCHAR(100),
    system_physical_memory_high NVARCHAR(100),
    system_physical_memory_low NVARCHAR(100),
    process_physical_memory_low NVARCHAR(100),
    process_virtual_memory_low NVARCHAR(100),
    dma_source_id NVARCHAR(512),
    dma_manual_id NVARCHAR(512)
);

BEGIN TRY
    INSERT INTO #MemUsage
    SELECT
        '"' + @PKEY + '"' AS PKEY,
        '"' + CONVERT(NVARCHAR(30), x.event_xml.value('(/event/@timestamp)[1]', 'datetime2'), 126) + '"' AS [timestamp],
        '"' + CONVERT(NVARCHAR(50), x.event_xml.value('(/event/data[@name="state"]/text)[1]', 'nvarchar(50)')) + '"' AS [state],
        '"' + CONVERT(NVARCHAR(30), x.event_xml.value('(//entry[@description="Available Physical Memory"]/@value)[1]', 'bigint') / 1024 / 1024) + '"' AS available_physical_memory_mb,
        '"' + CONVERT(NVARCHAR(30), x.event_xml.value('(//entry[@description="Working Set"]/@value)[1]', 'bigint') / 1024 / 1024) + '"' AS working_set_mb,
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(//entry[@description="Percent of Committed Memory in WS"]/@value)[1]', 'int')) + '"' AS percent_committed_in_ws,
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(//entry[@description="System physical memory high"]/@value)[1]', 'int')) + '"' AS system_physical_memory_high,
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(//entry[@description="System physical memory low"]/@value)[1]', 'int')) + '"' AS system_physical_memory_low,
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(//entry[@description="Process physical memory low"]/@value)[1]', 'int')) + '"' AS process_physical_memory_low,
        '"' + CONVERT(NVARCHAR(20), x.event_xml.value('(//entry[@description="Process virtual memory low"]/@value)[1]', 'int')) + '"' AS process_virtual_memory_low,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
    FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL) AS f
    CROSS APPLY (SELECT TRY_CAST(f.event_data AS XML) AS event_xml) AS x
    WHERE f.object_name = 'sp_server_diagnostics_component_result'
      AND x.event_xml IS NOT NULL
      AND x.event_xml.value('(/event/@timestamp)[1]', 'datetime2') >= DATEADD(day, -7, GETDATE())
      AND x.event_xml.value('(/event/data[@name="component"]/text)[1]', 'nvarchar(100)') = 'RESOURCE';
END TRY
BEGIN CATCH
    -- Gracefully return 0 rows on Azure SQL Database or restricted hosts without system_health XEL file access
END CATCH;

SELECT *
FROM #MemUsage
ORDER BY timestamp DESC;

IF OBJECT_ID('tempdb..#MemUsage') IS NOT NULL
    DROP TABLE #MemUsage;
