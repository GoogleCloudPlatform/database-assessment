/*
Copyright 2024 Google LLC

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
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @validDB AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE';
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @validDB = 0;
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

BEGIN
    BEGIN
        SELECT @validDB = COUNT(1)
        FROM sys.databases
        WHERE name NOT IN ('master','model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
            AND name like @ASSESSMENT_DATABSE_NAME
            AND state = 0
            AND is_read_only = 0
    END

    BEGIN TRY
        IF @validDB <> 0
        BEGIN
        SELECT
            '"' + @PKEY + '"' as PKEY,
            '"' + CONVERT(NVARCHAR(255),sizing.database_name) + '"' as database_name,
            '"' + CONVERT(NVARCHAR(255),sizing.type_desc) + '"' as type_desc,
            '"' + CONVERT(NVARCHAR(255),sizing.current_size_mb) + '"' as current_size_mb,
            '"' + @DMA_SOURCE_ID + '"' as dma_source_id,
            '"' + @DMA_MANUAL_ID + '"' as dma_manual_id,
			'"' + CONVERT(NVARCHAR(255),sizing.recovery_model_desc) + '"' as recovery_model_desc
        FROM(
            SELECT
                db_name() AS database_name,
                type_desc,
                SUM(size/128.0) AS current_size_mb,
				d.recovery_model_desc AS recovery_model_desc
            FROM sys.database_files sm
			CROSS JOIN sys.databases d
            WHERE db_name() NOT IN ('master', 'model', 'msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
			    AND d.name = db_name()
                AND sm.type IN (0,1)
                AND d.state = 0
                AND d.is_read_only = 0
                AND EXISTS (SELECT 1
                FROM sys.databases sd
                WHERE sd.state = 0
                    AND sd.name NOT IN ('master','model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
                    AND sd.name like @ASSESSMENT_DATABSE_NAME
                    AND sd.state = 0
                    AND sd.is_read_only = 0
                    AND sd.name =db_name())
            GROUP BY sm.type_desc, d.recovery_model_desc) sizing
    END
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            WAITFOR DELAY '00:00:00'
        ELSE
        SELECT
        host_name() as host_name,
        db_name() as database_name,
        'dbSizes' as module_name,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_NUMBER()),1,254) as error_number,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_SEVERITY()),1,254) as error_severity,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_STATE()),1,254) as error_state,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_MESSAGE()),1,512) as error_message
    END CATCH
END;
