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
    '"' + RTRIM(LTRIM(CONVERT(NVARCHAR(MAX), instance_name))) + '"' AS FeatureName,
    '"' + CONVERT(NVARCHAR(MAX), cntr_value) + '"' AS UsageCount,
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
FROM
    sys.dm_os_performance_counters
WHERE
    object_name LIKE '%Deprecated Features%'
    AND cntr_value > 0
ORDER BY
    cntr_value DESC;
