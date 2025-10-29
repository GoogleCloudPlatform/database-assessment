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

DECLARE @PKEY AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

BEGIN
    IF @CLOUDTYPE = 'NONE'
    BEGIN TRY
        exec('
        SELECT DISTINCT
            ''"' + @PKEY + '"'' AS pkey,
            ''"'' + CONVERT(NVARCHAR(MAX), vs.volume_mount_point) + ''"'' as volume_mount_point,
            ''"'' + CONVERT(NVARCHAR(MAX), vs.file_system_type) + ''"'' as file_system_type,
            CASE WHEN LEN(vs.logical_volume_name) > 0
            THEN ''"'' + CONVERT(NVARCHAR(MAX), vs.logical_volume_name) + ''"''
            ELSE ''""''
            END as logical_volume_name,
            ''"'' + CONVERT(NVARCHAR(MAX), ROUND(CONVERT(FLOAT, vs.total_bytes / 1073741824.0),2)) + ''"'' AS total_size_gb,
            ''"'' + CONVERT(NVARCHAR(MAX), ROUND(CONVERT(FLOAT, vs.available_bytes / 1073741824.0),2)) + ''"'' AS available_size_gb,
            ''"'' + CONVERT(NVARCHAR(MAX), ROUND(CONVERT(FLOAT, vs.available_bytes) / CONVERT(FLOAT, vs.total_bytes),2)*100) + ''"'' AS space_free_pct,
            ''""'' as cluster_block_size,
            ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
            ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
        FROM
            sys.master_files AS f WITH (
                NOLOCK)
            CROSS APPLY sys.dm_os_volume_stats (f.database_id, f.[file_id]) AS vs OPTION (RECOMPILE)');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            WAITFOR DELAY '00:00:00'
    END CATCH
    IF @CLOUDTYPE = 'AZURE'
    BEGIN TRY
        exec('
        WITH db_sizes as (SELECT MAX(start_time) max_collection_time
            , database_name, MAX(storage_in_megabytes) storage_in_megabytes
            , MAX(allocated_storage_in_megabytes) allocated_storage_in_megabytes
        FROM sys.resource_stats
        GROUP BY database_name),
        sum_sizes as (SELECT sum(storage_in_megabytes/1024) total_size_gb
        ,sum(allocated_storage_in_megabytes/1024) available_size_gb
        FROM db_sizes)
        SELECT
            ''"' + @PKEY + '"'' AS pkey,
            ''"CLOUD"'' as volume_mount_point,
            ''"AZURE"'' as file_system_type,
            ''"CLOUD"'' as logical_volume_name,
            ''"'' + CONVERT(NVARCHAR(255), ROUND(CONVERT(FLOAT, total_size_gb),2)) + ''"'' as total_size_gb,
            ''"'' + CONVERT(NVARCHAR(255), ROUND(CONVERT(FLOAT, available_size_gb),2)) + ''"'' as available_size_gb,
            ''"'' + CONVERT(NVARCHAR(255), ROUND((1 - (total_size_gb / available_size_gb)) * 100,2)) + ''"'' as space_free_pct,
            ''""'' as cluster_block_size,
            ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
            ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
        FROM sum_sizes');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            WAITFOR DELAY '00:00:00'
    END CATCH
END;
