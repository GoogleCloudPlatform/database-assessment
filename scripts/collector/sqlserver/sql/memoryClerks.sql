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
SET TRANSACTION ISOLATION LEVEL READ UNCOMMITTED;
SET LANGUAGE us_english;

DECLARE @PKEY AS VARCHAR(256);
DECLARE @DMA_SOURCE_ID AS VARCHAR(256);
DECLARE @DMA_MANUAL_ID AS VARCHAR(256);

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

DECLARE @PRODUCT_VERSION AS INT;
SELECT @PRODUCT_VERSION = CONVERT(INT, (@@microsoftversion / 0x1000000) & 0xff);

IF @PRODUCT_VERSION >= 11
BEGIN
    EXEC sys.sp_executesql
        N'WITH TotalMemory AS (
            SELECT
                ISNULL(NULLIF(SUM(pages_kb), 0), 1) AS total_pages_kb
            FROM sys.dm_os_memory_clerks
        )
        SELECT TOP (20)
            ''"'' + @PKEY + ''"'' AS PKEY,
            ''"'' + CONVERT(NVARCHAR(128), mc.type) + ''"'' AS memory_clerk_type,
            ''"'' + CONVERT(NVARCHAR(30), SUM(mc.pages_kb) / 1024) + ''"'' AS allocated_mb,
            ''"'' + CONVERT(NVARCHAR(20), CAST((SUM(mc.pages_kb) * 100.0 / tm.total_pages_kb) AS DECIMAL(5,2))) + ''"'' AS pct_of_total_sql_memory,
            ''"'' + @DMA_SOURCE_ID + ''"'' AS dma_source_id,
            ''"'' + @DMA_MANUAL_ID + ''"'' AS dma_manual_id
        FROM sys.dm_os_memory_clerks mc
        CROSS JOIN TotalMemory tm
        GROUP BY mc.type, tm.total_pages_kb
        ORDER BY SUM(mc.pages_kb) DESC;',
        N'@PKEY VARCHAR(256), @DMA_SOURCE_ID VARCHAR(256), @DMA_MANUAL_ID VARCHAR(256)',
        @PKEY = @PKEY,
        @DMA_SOURCE_ID = @DMA_SOURCE_ID,
        @DMA_MANUAL_ID = @DMA_MANUAL_ID;
END
ELSE
BEGIN
    EXEC sys.sp_executesql
        N'WITH TotalMemory AS (
            SELECT
                ISNULL(NULLIF(SUM(single_pages_kb + multi_pages_kb), 0), 1) AS total_pages_kb
            FROM sys.dm_os_memory_clerks
        )
        SELECT TOP (20)
            ''"'' + @PKEY + ''"'' AS PKEY,
            ''"'' + CONVERT(NVARCHAR(128), mc.type) + ''"'' AS memory_clerk_type,
            ''"'' + CONVERT(NVARCHAR(30), SUM(mc.single_pages_kb + mc.multi_pages_kb) / 1024) + ''"'' AS allocated_mb,
            ''"'' + CONVERT(NVARCHAR(20), CAST((SUM(mc.single_pages_kb + mc.multi_pages_kb) * 100.0 / tm.total_pages_kb) AS DECIMAL(5,2))) + ''"'' AS pct_of_total_sql_memory,
            ''"'' + @DMA_SOURCE_ID + ''"'' AS dma_source_id,
            ''"'' + @DMA_MANUAL_ID + ''"'' AS dma_manual_id
        FROM sys.dm_os_memory_clerks mc
        CROSS JOIN TotalMemory tm
        GROUP BY mc.type, tm.total_pages_kb
        ORDER BY SUM(mc.single_pages_kb + mc.multi_pages_kb) DESC;',
        N'@PKEY VARCHAR(256), @DMA_SOURCE_ID VARCHAR(256), @DMA_MANUAL_ID VARCHAR(256)',
        @PKEY = @PKEY,
        @DMA_SOURCE_ID = @DMA_SOURCE_ID,
        @DMA_MANUAL_ID = @DMA_MANUAL_ID;
END;
