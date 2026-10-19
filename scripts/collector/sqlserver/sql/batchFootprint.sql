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

WITH BatchResponses AS (
    SELECT *
    FROM sys.dm_os_performance_counters
    WHERE object_name LIKE '%Batch Resp Statistics%'
      AND instance_name IN (
        'Elapsed Time:Requests',
        'Elapsed Time:Total(ms)'
      )
)
SELECT
    @PKEY AS PKEY,
    AvgRunTimeMS = CASE
        WHEN bcount.cntr_value = 0 THEN 0
        ELSE btime.cntr_value / bcount.cntr_value
    END,
    StatementCount = CAST(bcount.cntr_value AS BIGINT),
    bcount.counter_name,
    TotalElapsedTimeMS = btime.cntr_value,
    ExecutionTimePercent = ISNULL(CAST((100.0 * btime.cntr_value / NULLIF(SUM(btime.cntr_value) OVER (), 0)) AS DECIMAL(5, 2)), 0.0),
    ExecutionCountPercent = ISNULL(CAST((100.0 * bcount.cntr_value / NULLIF(SUM(bcount.cntr_value) OVER (), 0)) AS DECIMAL(5, 2)), 0.0),
    @DMA_SOURCE_ID AS dma_source_id,
    @DMA_MANUAL_ID AS dma_manual_id
FROM (
    SELECT *
    FROM BatchResponses
    WHERE instance_name = 'Elapsed Time:Requests'
) bcount
JOIN (
    SELECT *
    FROM BatchResponses
    WHERE instance_name = 'Elapsed Time:Total(ms)'
) btime ON bcount.counter_name = btime.counter_name
ORDER BY bcount.counter_name ASC;
