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

SELECT
    '"' + @PKEY + '"' AS PKEY,
    '"' + ISNULL(CONVERT(NVARCHAR(30), CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'datetime2'), 126), N'') + '"' AS [timestamp],
    '"' + ISNULL(CONVERT(NVARCHAR(50), CAST(event_data AS XML).value('(/event/data[@name="state"]/text)[1]', 'nvarchar(50)')), N'') + '"' AS [state],
    '"' + ISNULL(CONVERT(NVARCHAR(30), CAST(event_data AS XML).value('(//entry[@description="Available Physical Memory"]/@value)[1]', 'bigint') / 1024 / 1024), N'') + '"' AS available_physical_memory_mb,
    '"' + ISNULL(CONVERT(NVARCHAR(30), CAST(event_data AS XML).value('(//entry[@description="Working Set"]/@value)[1]', 'bigint') / 1024 / 1024), N'') + '"' AS working_set_mb,
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(//entry[@description="Percent of Committed Memory in WS"]/@value)[1]', 'int')), N'') + '"' AS percent_committed_in_ws,
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(//entry[@description="System physical memory high"]/@value)[1]', 'int')), N'') + '"' AS system_physical_memory_high,
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(//entry[@description="System physical memory low"]/@value)[1]', 'int')), N'') + '"' AS system_physical_memory_low,
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(//entry[@description="Process physical memory low"]/@value)[1]', 'int')), N'') + '"' AS process_physical_memory_low,
    '"' + ISNULL(CONVERT(NVARCHAR(20), CAST(event_data AS XML).value('(//entry[@description="Process virtual memory low"]/@value)[1]', 'int')), N'') + '"' AS process_virtual_memory_low,
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
FROM sys.fn_xe_file_target_read_file('system_health*.xel', NULL, NULL, NULL)
WHERE object_name = 'sp_server_diagnostics_component_result'
AND CAST(event_data AS XML).value('(/event/@timestamp)[1]', 'datetime2') >= DATEADD(day, -7, GETDATE())
AND CAST(event_data AS XML).value('(/event/data[@name="component"]/text)[1]', 'nvarchar(100)') = 'RESOURCE'
ORDER BY [timestamp] DESC;
