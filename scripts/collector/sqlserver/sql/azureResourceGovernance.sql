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

IF @CLOUDTYPE = 'AZURE' AND OBJECT_ID('sys.dm_user_db_resource_governance') IS NOT NULL
BEGIN
    SELECT
        '"' + @PKEY + '"' AS PKEY,
        '"' + CONVERT(NVARCHAR(MAX), database_id) + '"' AS database_id,
        '"' + CONVERT(NVARCHAR(MAX), logical_cpu_count) + '"' AS logical_cpu_count,
        '"' + CONVERT(NVARCHAR(MAX), process_memory_limit_mb) + '"' AS process_memory_limit_mb,
        '"' + CONVERT(NVARCHAR(MAX), max_global_index_size_mb) + '"' AS max_global_index_size_mb,
        '"' + CONVERT(NVARCHAR(MAX), user_data_cap_gb) + '"' AS user_data_cap_gb,
        '"' + CONVERT(NVARCHAR(MAX), user_data_iops_cap) + '"' AS user_data_iops_cap,
        '"' + CONVERT(NVARCHAR(MAX), log_write_cap_mb_sec) + '"' AS log_write_cap_mb_sec,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
    FROM sys.dm_user_db_resource_governance;
END
ELSE
BEGIN
    SELECT TOP 0
        '"' + @PKEY + '"' AS PKEY,
        '' AS database_id,
        '' AS logical_cpu_count,
        '' AS process_memory_limit_mb,
        '' AS max_global_index_size_mb,
        '' AS user_data_cap_gb,
        '' AS user_data_iops_cap,
        '' AS log_write_cap_mb_sec,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
    FROM sys.objects;
END
