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
set NOCOUNT on;

set LANGUAGE us_english;

declare @PKEY as VARCHAR(256)
declare @CLOUDTYPE as VARCHAR(256)
declare @PRODUCT_VERSION as INTEGER
declare @TABLE_PERMISSION_COUNT as INTEGER
declare @ROW_COUNT_VAR as INTEGER
declare @DMA_SOURCE_ID as VARCHAR(256)
declare @DMA_MANUAL_ID as VARCHAR(256)
select @PKEY = N'$(pkey)';

select @CLOUDTYPE = 'NONE';

select @PRODUCT_VERSION = convert(
        INTEGER,
        PARSENAME(
            convert(nvarchar, SERVERPROPERTY('productversion')),
            4
        )
    );

select @DMA_SOURCE_ID = N'$(dmaSourceId)';

CREATE TABLE #FeaturesEnabledDbLevel
(
    database_name nvarchar(255) DEFAULT db_name(),
    feature_name NVARCHAR(40),
    is_enabled_or_used NVARCHAR(1),
    occurance_count INT
);

if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE' if OBJECT_ID('tempdb..#FeaturesEnabledDbLevel') is not null drop table #FeaturesEnabledDbLevel;
    create table #FeaturesEnabledDbLevel
    (
        database_name nvarchar(255) default db_name(),
        feature_name NVARCHAR(40),
        is_enabled_or_used NVARCHAR(1),
        occurance_count INT
    ) --Security Policies
    begin TRY exec(
        'INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''SP'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.security_policies
            WHERE is_enabled = 1'
    )
    /* SQL Server 2016 (13.x) and above */
;

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 begin exec(
    'INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SP'', ''0'', 0'
)
/* SQL Server 2014 (12.x) and below */
;

end
else begin exec(
    'INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SP'', ''0'', 0'
)
/* SQL Server 2014 (12.x) and below */
;

end
end CATCH --File Tables Detected
begin TRY exec(
    'INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''IsFileTablesEnabled'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.filetables
            WHERE is_enabled = 1'
)
/* SQL Server 2016 (13.x) and above */
;

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 begin exec(
    'INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsFileTablesEnabled'', ''0'', 0'
)
/* SQL Server 2014 (12.x) and below */
;

end
else begin exec(
    'INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsFileTablesEnabled'', ''0'', 0'
)
/* SQL Server 2014 (12.x) and below */
;

end
end CATCH
/* Collect permissions which are unsupported in CloudSQL SQL Server */
begin begin TRY exec(
    'INSERT INTO #FeaturesEnabledDbLevel
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
                    tmp.permission_name'
);

SELECT
    QUOTENAME(@PKEY,'"') as PKEY,
    QUOTENAME(f.database_name,'"') as database_name,
    QUOTENAME(f.feature_name,'"') as feature_name,
    QUOTENAME(f.is_enabled_or_used,'"') as is_enabled_or_used,
    QUOTENAME(f.occurance_count,'"') as occurance_count,
    QUOTENAME(@DMA_SOURCE_ID,'"') as dma_source_id,
    QUOTENAME(@DMA_MANUAL_ID,'"') as dma_manual_id
FROM #FeaturesEnabledDbLevel f;

IF OBJECT_ID('tempdb..#FeaturesEnabledDbLevel') IS NOT NULL  
   DROP TABLE #FeaturesEnabledDbLevel;
