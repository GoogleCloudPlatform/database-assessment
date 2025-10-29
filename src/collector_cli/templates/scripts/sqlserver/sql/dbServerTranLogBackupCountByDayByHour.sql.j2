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
        ''"'' + CONVERT(NVARCHAR(MAX), COUNT (1)) + ''"'' as total_logs_generated,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 00, 1, 0))) + ''"'' as h0_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 01, 1, 0))) + ''"'' as h1_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 02, 1, 0))) + ''"'' as h2_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 03, 1, 0))) + ''"'' as h3_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 04, 1, 0))) + ''"'' as h4_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 05, 1, 0))) + ''"'' as h5_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 06, 1, 0))) + ''"'' as h6_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 07, 1, 0))) + ''"'' as h7_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 08, 1, 0))) + ''"'' as h8_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 09, 1, 0))) + ''"'' as h9_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 10, 1, 0))) + ''"'' as h10_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 11, 1, 0))) + ''"'' as h11_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 12, 1, 0))) + ''"'' as h12_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 13, 1, 0))) + ''"'' as h13_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 14, 1, 0))) + ''"'' as h14_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 15, 1, 0))) + ''"'' as h15_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 16, 1, 0))) + ''"'' as h16_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 17, 1, 0))) + ''"'' as h17_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 18, 1, 0))) + ''"'' as h18_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 19, 1, 0))) + ''"'' as h19_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 20, 1, 0))) + ''"'' as h20_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 21, 1, 0))) + ''"'' as h21_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 22, 1, 0))) + ''"'' as h22_count,
        ''"'' + CONVERT(NVARCHAR(MAX), SUM (IIF (DATEPART (hh, a.backup_start_date) = 23, 1, 0))) + ''"'' as h23_count,
        ''"'' + CONVERT(NVARCHAR(MAX), CEILING(ROUND (COUNT (1) / 24, 0))) + ''"'' as avg_per_hour,
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
