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
DECLARE @CLOUDTYPE AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';
SELECT @CLOUDTYPE = 'NONE';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE';

IF @CLOUDTYPE = 'AZURE' AND OBJECT_ID('sys.elastic_pool_resource_stats') IS NOT NULL
BEGIN
    SELECT
        '"' + @PKEY + '"' AS PKEY,
        '"' + CONVERT(NVARCHAR(MAX), end_time, 121) + '"' AS end_time,
        '"' + REPLACE(ISNULL(CONVERT(NVARCHAR(MAX), elastic_pool_name), N''), '"', '""') + '"' AS elastic_pool_name,
        '"' + CONVERT(NVARCHAR(MAX), avg_cpu_percent) + '"' AS avg_cpu_percent,
        '"' + CONVERT(NVARCHAR(MAX), avg_data_io_percent) + '"' AS avg_data_io_percent,
        '"' + CONVERT(NVARCHAR(MAX), avg_log_write_percent) + '"' AS avg_log_write_percent,
        '"' + CONVERT(NVARCHAR(MAX), max_worker_percent) + '"' AS max_worker_percent,
        '"' + CONVERT(NVARCHAR(MAX), elastic_pool_dtu_limit) + '"' AS elastic_pool_dtu_limit,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
    FROM sys.elastic_pool_resource_stats
    ORDER BY end_time DESC;
END
ELSE
BEGIN
    SELECT TOP 0
        '"' + @PKEY + '"' AS PKEY,
        '' AS end_time,
        '' AS elastic_pool_name,
        '' AS avg_cpu_percent,
        '' AS avg_data_io_percent,
        '' AS avg_log_write_percent,
        '' AS max_worker_percent,
        '' AS elastic_pool_dtu_limit,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
    FROM sys.objects;
END
