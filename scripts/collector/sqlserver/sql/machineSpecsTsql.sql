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
DECLARE @MACHINENAME AS NVARCHAR(256)
DECLARE @PRODUCT_VERSION AS INT

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';
SELECT @MACHINENAME = CONVERT(NVARCHAR(256), SERVERPROPERTY('MachineName'));
SELECT @PRODUCT_VERSION = CONVERT(INT, (@@microsoftversion / 0x1000000) & 0xff);

IF @PRODUCT_VERSION >= 11
BEGIN
    EXEC sys.sp_executesql
        N'SELECT
            ''"'' + @PKEY + ''"'' AS pkey,
            ''"'' + @DMA_SOURCE_ID + ''"'' AS dma_source_id,
            ''"'' + @DMA_MANUAL_ID + ''"'' AS dma_manual_id,
            ''"'' + REPLACE(ISNULL(@MACHINENAME, N''''), ''"'', ''""'') + ''"'' AS MachineName,
            ''"'' + CONVERT(NVARCHAR(255), socket_count) + ''"'' AS PhysicalCpuCount,
            ''"'' + CONVERT(NVARCHAR(255), cpu_count) + ''"'' AS LogicalCpuCount,
            ''"'' + CONVERT(NVARCHAR(255), physical_memory_kb / 1024) + ''"'' AS TotalOSMemoryMB
        FROM sys.dm_os_sys_info;',
        N'@PKEY VARCHAR(256), @DMA_SOURCE_ID VARCHAR(256), @DMA_MANUAL_ID VARCHAR(256), @MACHINENAME NVARCHAR(256)',
        @PKEY = @PKEY,
        @DMA_SOURCE_ID = @DMA_SOURCE_ID,
        @DMA_MANUAL_ID = @DMA_MANUAL_ID,
        @MACHINENAME = @MACHINENAME;
END
ELSE
BEGIN
    EXEC sys.sp_executesql
        N'SELECT
            ''"'' + @PKEY + ''"'' AS pkey,
            ''"'' + @DMA_SOURCE_ID + ''"'' AS dma_source_id,
            ''"'' + @DMA_MANUAL_ID + ''"'' AS dma_manual_id,
            ''"'' + REPLACE(ISNULL(@MACHINENAME, N''''), ''"'', ''""'') + ''"'' AS MachineName,
            ''"'' + CONVERT(NVARCHAR(255), CASE WHEN hyperthread_ratio > 0 THEN cpu_count / hyperthread_ratio ELSE cpu_count END) + ''"'' AS PhysicalCpuCount,
            ''"'' + CONVERT(NVARCHAR(255), cpu_count) + ''"'' AS LogicalCpuCount,
            ''"'' + CONVERT(NVARCHAR(255), physical_memory_in_bytes / 1048576) + ''"'' AS TotalOSMemoryMB
        FROM sys.dm_os_sys_info;',
        N'@PKEY VARCHAR(256), @DMA_SOURCE_ID VARCHAR(256), @DMA_MANUAL_ID VARCHAR(256), @MACHINENAME NVARCHAR(256)',
        @PKEY = @PKEY,
        @DMA_SOURCE_ID = @DMA_SOURCE_ID,
        @DMA_MANUAL_ID = @DMA_MANUAL_ID,
        @MACHINENAME = @MACHINENAME;
END;
