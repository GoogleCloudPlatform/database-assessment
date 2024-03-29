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

IF OBJECT_ID('tempdb..#serverTranLogBackupSize') IS NOT NULL  
    DROP TABLE #serverTranLogBackupSize;

CREATE TABLE #serverTranLogBackupSize (
    collection_date nvarchar(256), 
    day_of_month nvarchar(256),
    total_logs_generated_in_mb nvarchar(256),
    h0_size_in_mb nvarchar(256),
    h1_size_in_mb nvarchar(256),
    h2_size_in_mb nvarchar(256),
    h3_size_in_mb nvarchar(256),
    h4_size_in_mb nvarchar(256),
    h5_size_in_mb nvarchar(256),
    h6_size_in_mb nvarchar(256),
    h7_size_in_mb nvarchar(256),
    h8_size_in_mb nvarchar(256),
    h9_size_in_mb nvarchar(256),
    h10_size_in_mb nvarchar(256),
    h11_size_in_mb nvarchar(256),
    h12_size_in_mb nvarchar(256),
    h13_size_in_mb nvarchar(256),
    h14_size_in_mb nvarchar(256),
    h15_size_in_mb nvarchar(256),
    h16_size_in_mb nvarchar(256),
    h17_size_in_mb nvarchar(256),
    h18_size_in_mb nvarchar(256),
    h19_size_in_mb nvarchar(256),
    h20_size_in_mb nvarchar(256),
    h21_size_in_mb nvarchar(256),
    h22_size_in_mb nvarchar(256),
    h23_size_in_mb nvarchar(256),
    avg_mb_per_hour nvarchar(256)
);

BEGIN
IF @PRODUCT_VERSION > 10
    exec('
    INSERT INTO #serverTranLogBackupSize
    SELECT
        CONVERT(VARCHAR(19), a.backup_start_date, 101) AS collection_date,
        DATEPART (day, a.backup_start_date) day_of_month,
        CEILING(ROUND(SUM(CONVERT(float,a.backup_size) / 1048576),0)) total_logs_generated_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 00, CEILING(a.backup_size / 1048576), 0)) h0_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 01, CEILING(a.backup_size / 1048576), 0)) h1_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 02, CEILING(a.backup_size / 1048576), 0)) h2_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 03, CEILING(a.backup_size / 1048576), 0)) h3_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 04, CEILING(a.backup_size / 1048576), 0)) h4_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 05, CEILING(a.backup_size / 1048576), 0)) h5_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 06, CEILING(a.backup_size / 1048576), 0)) h6_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 07, CEILING(a.backup_size / 1048576), 0)) h7_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 08, CEILING(a.backup_size / 1048576), 0)) h8_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 09, CEILING(a.backup_size / 1048576), 0)) h9_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 10, CEILING(a.backup_size / 1048576), 0)) h10_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 11, CEILING(a.backup_size / 1048576), 0)) h11_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 12, CEILING(a.backup_size / 1048576), 0)) h12_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 13, CEILING(a.backup_size / 1048576), 0)) h13_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 14, CEILING(a.backup_size / 1048576), 0)) h14_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 15, CEILING(a.backup_size / 1048576), 0)) h15_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 16, CEILING(a.backup_size / 1048576), 0)) h16_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 17, CEILING(a.backup_size / 1048576), 0)) h17_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 18, CEILING(a.backup_size / 1048576), 0)) h18_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 19, CEILING(a.backup_size / 1048576), 0)) h19_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 20, CEILING(a.backup_size / 1048576), 0)) h20_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 21, CEILING(a.backup_size / 1048576), 0)) h21_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 22, CEILING(a.backup_size / 1048576), 0)) h22_size_in_mb,
        SUM (IIF (DATEPART (hh, a.backup_start_date) = 23, CEILING(a.backup_size / 1048576), 0)) h23_size_in_mb,
        CEILING(ROUND (SUM(CONVERT(float,a.backup_size) / 1048576) / 24, 0)) avg_mb_per_hour
    FROM msdb.dbo.backupset a
    WHERE a.type = ''L''
        AND a.backup_start_date < getdate()
    GROUP BY
        CONVERT(VARCHAR(19), a.backup_start_date, 101),
        DATEPART (day, a.backup_start_date) 
    ORDER BY 1,2');

SELECT 
    @PKEY as PKEY,
    collection_date, 
    day_of_month,
    total_logs_generated_in_mb,
    h0_size_in_mb,
    h1_size_in_mb,
    h2_size_in_mb,
    h3_size_in_mb,
    h4_size_in_mb,
    h5_size_in_mb,
    h6_size_in_mb,
    h7_size_in_mb,
    h8_size_in_mb,
    h9_size_in_mb,
    h10_size_in_mb,
    h11_size_in_mb,
    h12_size_in_mb,
    h13_size_in_mb,
    h14_size_in_mb,
    h15_size_in_mb,
    h16_size_in_mb,
    h17_size_in_mb,
    h18_size_in_mb,
    h19_size_in_mb,
    h20_size_in_mb,
    h21_size_in_mb,
    h22_size_in_mb,
    h23_size_in_mb,
    avg_mb_per_hour,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #serverTranLogBackupSize;
END

IF OBJECT_ID('tempdb..#serverTranLogBackupSize') IS NOT NULL  
    DROP TABLE #serverTranLogBackupSize;