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
DECLARE @TABLE_PERMISSION_COUNT AS INTEGER
DECLARE @ROW_COUNT_VAR AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF OBJECT_ID('tempdb..#FeaturesEnabledDbLevel') IS NOT NULL
   DROP TABLE #FeaturesEnabledDbLevel;

CREATE TABLE #FeaturesEnabledDbLevel
(
    database_name nvarchar(255) DEFAULT db_name(),
    feature_name NVARCHAR(40),
    is_enabled_or_used NVARCHAR(1),
    occurance_count INT
);

--Security Policies
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''SP'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.security_policies
            WHERE is_enabled = 1') /* SQL Server 2016 (13.x) and above */ ;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SP'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
    ELSE
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SP'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
END CATCH

--File Tables Detected
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''IsFileTablesEnabled'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.filetables
            WHERE is_enabled = 1') /* SQL Server 2016 (13.x) and above */ ;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsFileTablesEnabled'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
    ELSE
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsFileTablesEnabled'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
END CATCH

/* Collect permissions which are unsupported in CloudSQL SQL Server */
BEGIN
    BEGIN TRY
            exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT
                    db_name(),
                    tmp.permission_name,
					CASE WHEN count(1) > 0 THEN 1 ELSE 0 END,
                    count(1)
                FROM (
                    SELECT
                        pr.name,
                        pr.type,
                        pr.type_desc,
                        dp.permission_name,
                        dp.type AS permission_type
                    FROM
                        sys.database_permissions dp
                        INNER JOIN sys.server_principals pr ON dp.grantee_principal_id = pr.principal_id
                    WHERE
                        pr.name NOT LIKE ''NT SERVICE\%''
                        AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'',
                        ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'',
                        ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'',
                        ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'',
                        ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')) tmp
                GROUP BY
                    tmp.permission_name');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            WAITFOR DELAY '00:00:00'
    END CATCH
END

SELECT
    '"' + @PKEY + '"' as PKEY,
    '"' + CONVERT(NVARCHAR(MAX), f.database_name) + '"' as database_name,
    '"' + CONVERT(NVARCHAR(MAX), f.feature_name) + '"' as feature_name,
    '"' + CONVERT(NVARCHAR(MAX), f.is_enabled_or_used) + '"' as is_enabled_or_used,
    '"' + CONVERT(NVARCHAR(MAX), f.occurance_count) + '"' as occurance_count,
    '"' + @DMA_SOURCE_ID + '"' as dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' as dma_manual_id
FROM #FeaturesEnabledDbLevel f;

IF OBJECT_ID('tempdb..#FeaturesEnabledDbLevel') IS NOT NULL
   DROP TABLE #FeaturesEnabledDbLevel;
