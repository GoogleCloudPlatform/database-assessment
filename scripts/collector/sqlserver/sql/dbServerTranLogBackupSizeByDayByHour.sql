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
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

BEGIN
IF @PRODUCT_VERSION > 10
    exec('
    SELECT
        ''"' + @PKEY + '"'' AS pkey,
        ''"'' + CONVERT(VARCHAR(19), a.backup_start_date, 101) + ''"'' as collection_date,
        ''"'' + CONVERT(NVARCHAR(MAX), DATEPART(day, a.backup_start_date)) + ''"'' as day_of_month,
        ''"'' + CONVERT(NVARCHAR(MAX), CEILING(ROUND(SUM(CONVERT(float,a.backup_size) / 1048576),0))) + ''"'' as total_logs_generated_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 00, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h0_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 01, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h1_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 02, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h2_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 03, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h3_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 04, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h4_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 05, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h5_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 06, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h6_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 07, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h7_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 08, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h8_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 09, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h9_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 10, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h10_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 11, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h11_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 12, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h12_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 13, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h13_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 14, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h14_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 15, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h15_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 16, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h16_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 17, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h17_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 18, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h18_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 19, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h19_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 20, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h20_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 21, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h21_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 22, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h22_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 23, CEILING(a.backup_size / 1048576), 0))) + ''"'' as h23_size_in_mb,
        ''"'' + CONVERT(NVARCHAR(MAX), CEILING(ROUND (SUM(CONVERT(float,a.backup_size) / 1048576) / 24, 0))) + ''"'' as avg_mb_per_hour,
        ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
    FROM msdb.dbo.backupset a
    WHERE a.type = ''L''
        AND a.backup_start_date < getdate()
    GROUP BY
        CONVERT(VARCHAR(19), a.backup_start_date, 101),
        DATEPART (day, a.backup_start_date)
    ORDER BY 1,2');
END;
