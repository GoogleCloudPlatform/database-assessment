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
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF OBJECT_ID('tempdb..#gcpDMADiskVolumeInfo') IS NOT NULL  
   DROP TABLE #gcpDMADiskVolumeInfo;  

CREATE TABLE #gcpDMADiskVolumeInfo
(
volume_mount_point NVARCHAR(255),
file_system_type NVARCHAR(255),
logical_volume_name NVARCHAR(255),
total_size_gb NVARCHAR(255),
available_size_gb NVARCHAR(255),
space_free_pct NVARCHAR(255),
cluster_block_size NVARCHAR(255)
)

IF @CLOUDTYPE = 'NONE'
    exec('
    INSERT INTO #gcpDMADiskVolumeInfo
    SELECT DISTINCT
        vs.volume_mount_point,
        vs.file_system_type,
		CASE WHEN LEN(vs.logical_volume_name) > 0
		   THEN vs.logical_volume_name
		ELSE ''''
		END,
        CONVERT(NVARCHAR, (vs.total_bytes / 1073741824.0)) AS total_size_gb,
        CONVERT(NVARCHAR, (vs.available_bytes / 1073741824.0)) AS available_size_gb,
        CONVERT(NVARCHAR, ROUND((CONVERT(numeric,vs.available_bytes) / CONVERT(numeric, vs.total_bytes)),4)) AS space_free_pct,
        '''' as cluster_block_size
    FROM
        sys.master_files AS f WITH (
            NOLOCK)
        CROSS APPLY sys.dm_os_volume_stats (f.database_id, f.[file_id]) AS vs OPTION (RECOMPILE)');
IF @CLOUDTYPE = 'AZURE'
    exec('
    WITH db_sizes as (SELECT MAX(start_time) max_collection_time
        , database_name, MAX(storage_in_megabytes) storage_in_megabytes
        , MAX(allocated_storage_in_megabytes) allocated_storage_in_megabytes
    FROM sys.resource_stats 
    GROUP BY database_name),
    sum_sizes as (SELECT sum(storage_in_megabytes/1024) total_size_gb
    ,sum(allocated_storage_in_megabytes/1024) available_size_gb
    FROM db_sizes)
    INSERT INTO #gcpDMADiskVolumeInfo
    SELECT 
        ''CLOUD'' as volume_mount_point, 
        ''AZURE'' as file_system_type, 
        ''CLOUD'' as logical_volume_name, 
        total_size_gb, 
        available_size_gb, 
        total_size_gb/available_size_gb as space_free_pct,
        '''' as cluster_block_size
    FROM sum_sizes');

SELECT 
    @PKEY as PKEY, 
    a.*, 
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #gcpDMADiskVolumeInfo a;

IF OBJECT_ID('tempdb..#gcpDMADiskVolumeInfo') IS NOT NULL  
   DROP TABLE #gcpDMADiskVolumeInfo;