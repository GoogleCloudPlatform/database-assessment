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
SET QUOTED_IDENTIFIER ON;

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

IF OBJECT_ID('tempdb..#serverTranLogCount') IS NOT NULL  
    DROP TABLE #serverTranLogCount;

CREATE TABLE #serverTranLogCount (
    collection_date nvarchar(256), 
    day_of_month nvarchar(256),
    total_logs_generated nvarchar(256),
    h0_count nvarchar(256),
    h1_count nvarchar(256),
    h2_count nvarchar(256),
    h3_count nvarchar(256),
    h4_count nvarchar(256),
    h5_count nvarchar(256),
    h6_count nvarchar(256),
    h7_count nvarchar(256),
    h8_count nvarchar(256),
    h9_count nvarchar(256),
    h10_count nvarchar(256),
    h11_count nvarchar(256),
    h12_count nvarchar(256),
    h13_count nvarchar(256),
    h14_count nvarchar(256),
    h15_count nvarchar(256),
    h16_count nvarchar(256),
    h17_count nvarchar(256),
    h18_count nvarchar(256),
    h19_count nvarchar(256),
    h20_count nvarchar(256),
    h21_count nvarchar(256),
    h22_count nvarchar(256),
    h23_count nvarchar(256),
    avg_per_hour nvarchar(256)
);

BEGIN
    INSERT INTO #serverTranLogCount
    SELECT
        CONVERT(VARCHAR(19), a.backup_start_date, 101) AS "collection_date",
        DATEPART (day, a.backup_start_date) "day_of_month",
        COUNT (1) "total_logs_generated",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 00, 1, 0)) "h0_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 01, 1, 0)) "h1_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 02, 1, 0)) "h2_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 03, 1, 0)) "h3_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 04, 1, 0)) "h4_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 05, 1, 0)) "h5_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 06, 1, 0)) "h6_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 07, 1, 0)) "h7_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 08, 1, 0)) "h8_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 09, 1, 0)) "h9_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 10, 1, 0)) "h10_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 11, 1, 0)) "h11_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 12, 1, 0)) "h12_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 13, 1, 0)) "h13_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 14, 1, 0)) "h14_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 15, 1, 0)) "h15_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 16, 1, 0)) "h16_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 17, 1, 0)) "h17_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 18, 1, 0)) "h18_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 19, 1, 0)) "h19_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 20, 1, 0)) "h20_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 21, 1, 0)) "h21_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 22, 1, 0)) "h22_count",
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 23, 1, 0)) "h23_count",
        CEILING(ROUND (COUNT (1) / 24, 0)) "avg_per_hour"
    FROM msdb.dbo.backupset a
    WHERE a.type = 'L'
        AND a.backup_start_date < getdate()
    GROUP BY
        CONVERT(VARCHAR(19), a.backup_start_date, 101),
        DATEPART (day, a.backup_start_date) 
    ORDER BY 1,2;

SELECT 
    @PKEY as PKEY,
    collection_date, 
    day_of_month,
    total_logs_generated,
    h0_count,
    h1_count,
    h2_count,
    h3_count,
    h4_count,
    h5_count,
    h6_count,
    h7_count,
    h8_count,
    h9_count,
    h10_count,
    h11_count,
    h12_count,
    h13_count,
    h14_count,
    h15_count,
    h16_count,
    h17_count,
    h18_count,
    h19_count,
    h20_count,
    h21_count,
    h22_count,
    h23_count,
    avg_per_hour,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #serverTranLogCount;

IF OBJECT_ID('tempdb..#serverTranLogCount') IS NOT NULL  
    DROP TABLE #serverTranLogCount;