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

IF OBJECT_ID('tempdb..#FeaturesEnabled') IS NOT NULL
   DROP TABLE #FeaturesEnabled;

CREATE TABLE #FeaturesEnabled
(
    Features NVARCHAR(40),
    Is_EnabledOrUsed NVARCHAR(4),
    Count INT
);

IF OBJECT_ID('tempdb..#myPerms') IS NOT NULL
   DROP TABLE #myPerms;

CREATE TABLE #myPerms
(
    entity_name nvarchar(255),
    subentity_name nvarchar(255),
    permission_name nvarchar(255)
);

INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.sysmail_server', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.sysmail_profile', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.sysmail_profileaccount', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.sysmail_account', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.log_shipping_secondary_databases', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.log_shipping_primary_databases', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.sysmaintplan_subplans', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms
SELECT *
FROM fn_my_permissions('msdb.dbo.sysjobs', 'OBJECT')
WHERE permission_name = 'SELECT' and subentity_name ='';

--DB Mail
SELECT @TABLE_PERMISSION_COUNT = COUNT(*)
FROM #myPerms
WHERE LOWER(entity_name) IN ('dbo.sysmail_profile','dbo.sysmail_profileaccount','dbo.sysmail_account','dbo.sysmail_server')
    AND UPPER(permission_name) = 'SELECT';
IF @TABLE_PERMISSION_COUNT >= 4 AND @CLOUDTYPE = 'NONE'
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsDbMailEnabled'',
        CONVERT(NVARCHAR(255), value_in_use),
        CASE WHEN value_in_use > 0 THEN 1
        ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''Database Mail XPs''');
END
ELSE
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsDbMailEnabled'',
        ''0'',
        0
    FROM sys.configurations
    WHERE name = ''Database Mail XPs''');
END;

--external scripts enabled
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsExternalScriptsEnabled'',
        CONVERT(NVARCHAR(255), value_in_use),
        CASE WHEN value_in_use > 0 THEN 1
        ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''external scripts enabled''');
END

-- Data Quality Services
BEGIN
    BEGIN TRY
        exec('
        WITH dqs_service as (
        select count(*) as dqs_count from syslogins where name like ''##MS_dqs%'')
        INSERT INTO #FeaturesEnabled
            SELECT
                ''DATA QUALITY SERVICES'' as Features,
                CASE
                    WHEN dqs_count > 0 THEN 1
                    ELSE 0
                END AS Is_EnabledOrUsed,
                dqs_count as Count
            from dqs_service');
        END TRY
    BEGIN CATCH
        exec('
        WITH dqs_service as (
        select count(*) as dqs_count from sys.sql_logins where name like ''##MS_dqs%'')
        INSERT INTO #FeaturesEnabled
            SELECT
                ''DATA QUALITY SERVICES'' as Features,
                CASE
                    WHEN dqs_count > 0 THEN 1
                    ELSE 0
                END AS Is_EnabledOrUsed,
                dqs_count as Count
            from dqs_service');
        END CATCH
END;

--filestream enabled
IF @PRODUCT_VERSION >= 11
BEGIN
    BEGIN TRY
        exec('WITH check_filestream AS (
            SELECT
                name,
                ISNULL((SELECT count(1) FROM sys.master_files AS mf WHERE mf.database_id = db.database_id AND mf.type = 2),0) AS hasfs
            FROM sys.databases AS db
            WHERE state = 0
            AND is_read_only = 0
        )
        INSERT INTO #FeaturesEnabled SELECT
            ''IsFileStreamEnabled'',
            CASE WHEN sum(hasfs) > 0 THEN ''1''
            ELSE ''0''
            END,
            CASE WHEN sum(hasfs) > 0 THEN 1
            ELSE 0
            END
        FROM
            check_filestream
        /* SQL Server 2012 (11.x) above */');
    END TRY
    BEGIN CATCH
        exec('
        INSERT INTO #FeaturesEnabled VALUES (
            ''IsFileStreamEnabled'',
            ''0'',
            0)
        ');
    END CATCH
END
ELSE
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled VALUES (
        ''IsFileStreamEnabled'',
        ''0'',
        0)
    ');
END

--hybrid buffer pool enabled


IF @CLOUDTYPE = 'AZURE'
BEGIN
    exec('INSERT INTO #FeaturesEnabled
            SELECT ''IsHybridBufferPoolEnabled'',
            CONVERT(NVARCHAR(255),is_enabled),
            CASE
                WHEN is_configured > 0 THEN 1
                ELSE 0
            END
            from sys.server_memory_optimized_hybrid_buffer_pool_configuration
            /* SQL Server 2019 (15.x) and later versions */');
END
ELSE
BEGIN
    IF @PRODUCT_VERSION >= 15
    BEGIN
        SELECT @ROW_COUNT_VAR = count(*)
        from sys.server_memory_optimized_hybrid_buffer_pool_configuration;
        IF @ROW_COUNT_VAR = 0
        BEGIN
            exec('INSERT INTO #FeaturesEnabled
                    SELECT
                        ''IsHybridBufferPoolEnabled'',
                        ''0'',
                        0');
        END;
        IF @ROW_COUNT_VAR > 0
        BEGIN
            exec('INSERT INTO #FeaturesEnabled
                SELECT ''IsHybridBufferPoolEnabled'',
                COALESCE(CONVERT(NVARCHAR(255),is_enabled), 0),
                CASE
                    WHEN is_enabled > 0 THEN 1
                ELSE 0
                END
                from sys.server_memory_optimized_hybrid_buffer_pool_configuration
                /* SQL Server 2019 (15.x) and later versions */');
        END;
    END;
    ELSE
    BEGIN
        exec('INSERT INTO #FeaturesEnabled
            SELECT
            ''IsHybridBufferPoolEnabled'',
            ''0'',
            0
            /* Earlier than SQL Server 2019 (15.x) versions */');
    END;
END;

--log shipping enabled
SELECT @TABLE_PERMISSION_COUNT = COUNT(*)
FROM #myPerms
WHERE LOWER(entity_name) in ('dbo.log_shipping_primary_databases','dbo.log_shipping_secondary_databases') and UPPER(permission_name) = 'SELECT';
IF @TABLE_PERMISSION_COUNT >= 2 AND @CLOUDTYPE = 'NONE'
BEGIN
    exec('WITH log_shipping_count AS (
        SELECT
            count(*) log_shipping
        FROM
            msdb..log_shipping_primary_databases
        UNION ALL
        SELECT
            count(*) log_shipping
        FROM
            msdb..log_shipping_secondary_databases
    )
    INSERT INTO #FeaturesEnabled
		SELECT
        ''IsLogShippingEnabled'',
        COALESCE(CONVERT(varchar,sum(log_shipping)),''0''),
        COALESCE(sum(log_shipping),0))
    FROM
        log_shipping_count');
END;
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabled VALUES (''IsLogShippingEnabled'', ''0'', 0)');
END;

--maintenance plans enabled
SELECT @TABLE_PERMISSION_COUNT = COUNT(*)
FROM #myPerms
WHERE LOWER(entity_name) in ('dbo.sysmaintplan_subplans','dbo.sysjobs') and UPPER(permission_name) = 'SELECT';
IF @TABLE_PERMISSION_COUNT >= 2
BEGIN
    exec('INSERT INTO #FeaturesEnabled
        SELECT
        ''MaintenancePlansEnabled'',
        CASE WHEN COALESCE(count(*),0) > 0
            THEN ''1''
            ELSE ''0''
        END,
        CASE WHEN COALESCE(count(*),0) > 0
            THEN COALESCE(count(*),0)
            ELSE 0
        END
    FROM
        msdb..sysmaintplan_plans p
        INNER JOIN msdb..sysmaintplan_subplans sp ON p.id = sp.plan_id
        INNER JOIN msdb..sysjobs j ON sp.job_id = j.job_id
    WHERE
        j.[enabled] = 1');
END;
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabled VALUES (''MaintenancePlansEnabled'', ''0'', 0)');
END;

--Polybase Enabled
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsPolybaseEnabled'',
        CONVERT(NVARCHAR(255), value_in_use),
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''polybase enabled''');
END;

--Resource Governor
BEGIN
    exec ('INSERT INTO #FeaturesEnabled
    SELECT
        ''IsResourceGovernorEnabled'',
        CONVERT(NVARCHAR(255), is_enabled),
        CASE
            WHEN is_enabled > 0 THEN 1
            ELSE 0
        END
    FROM sys.resource_governor_configuration');
END;

--Stretch Database
IF @CLOUDTYPE = 'AZURE'
BEGIN
    exec('INSERT INTO #FeaturesEnabled
            SELECT
                ''IsStretchDatabaseEnabled'',
                CONVERT(NVARCHAR(255), count(*)),
                CONVERT(int, count(*))
            FROM sys.remote_data_archive_databases');
END

IF @CLOUDTYPE = 'NONE'
BEGIN
    IF @PRODUCT_VERSION >= 13 AND @PRODUCT_VERSION <= 16
    BEGIN
        exec('INSERT INTO #FeaturesEnabled
                SELECT
                    ''IsStretchDatabaseEnabled'',
                    CONVERT(NVARCHAR(255), count(*)),
                    CONVERT(int, count(*))
                FROM sys.remote_data_archive_databases /* SQL Server 2016 (13.x) and Up to 2022 */');
    END
    ELSE
    BEGIN
        exec('INSERT INTO #FeaturesEnabled VALUES (''IsStretchDatabaseEnabled'', ''0'', 0)');
    END
END

--TDE in Use
BEGIN
    exec('INSERT INTO #FeaturesEnabled
            SELECT
                ''IsTDEInUse'',
                CONVERT(NVARCHAR(255), count(*)),
                CONVERT(int, count(*))
            FROM sys.databases
            WHERE is_encrypted <> 0
            AND state = 0
            AND is_read_only = 0');
END

--TempDB Metadata Memory Optimized
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsTempDbMetadataMemoryOptimized'',
        CONVERT(NVARCHAR(255), value_in_use),
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''tempdb metadata memory-optimized''');
END;

--Sysadmin role
BEGIN
    WITH
        check_sysadmin_role
        AS
        (
                            SELECT
                    name,
                    type_desc,
                    is_disabled
                FROM
                    sys.server_principals
                WHERE
            IS_SRVROLEMEMBER ('sysadmin', name) = 1
                    AND name NOT LIKE '%NT SERVICE%'
                    AND name <> 'sa'
            UNION
                SELECT
                    name,
                    type_desc,
                    is_disabled
                FROM
                    sys.server_principals
                WHERE
            IS_SRVROLEMEMBER ('dbcreator', name) = 1
                    AND name NOT LIKE '%NT SERVICE%'
                    AND name <> 'sa'
        )
    INSERT INTO #FeaturesEnabled
    SELECT
        'sysadmin_role',
        CASE WHEN count(*) > 0
                THEN '1'
            ELSE '0'
			END,
        CASE WHEN count(*) > 0
                THEN count(*)
            ELSE 0
			END
    FROM
        check_sysadmin_role;
END;

--Server level triggers
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
                SELECT
                    ''ServerLevelTriggers'',
                    CASE
                        WHEN count(*) > 0
                        THEN ''1''
                        ELSE ''0''
                    END,
                    CONVERT(int, count(*))
                from sys.server_triggers');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #FeaturesEnabled
                    SELECT
                        ''ServerLevelTriggers'',
                        ''0'',
                        0 ');
    END CATCH
END;

--OPENROWSET
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''OPENROWSET'',
        CONVERT(NVARCHAR(255), value_in_use) ,
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''Ad Hoc Distributed Queries''');
END;

--ad hoc distributed queries / distributed transaction coordinator DTC
BEGIN
    exec('
    INSERT INTO #FeaturesEnabled
    SELECT
        ''ad hoc distributed queries'',
        CONVERT(NVARCHAR(255), value_in_use) ,
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''Ad Hoc Distributed Queries''');
END;

--BULK INSERT
INSERT INTO #FeaturesEnabled
SELECT
    'BULK_INSERT',
    CASE
            WHEN count(p.permission_name) > 0 THEN '1'
            ELSE '0'
        END,
    CONVERT(int,count(p.permission_name))
FROM fn_my_permissions(NULL, 'SERVER') p
WHERE permission_name like '%ADMINISTER BULK OPERATIONS%';

-- CountServiceBrokerEndpoints
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
            SELECT
                ''CountServiceBrokerEndpoints'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.service_broker_endpoints');
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
        exec('INSERT INTO #FeaturesEnabled SELECT ''CountServiceBrokerEndpoints'', ''0'', 0');
END CATCH

-- CountTSQLEndpoints
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
            SELECT
                ''CountTSQLEndpoints'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.tcp_endpoints
            WHERE endpoint_id > 65535');
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
    BEGIN
    exec('INSERT INTO #FeaturesEnabled SELECT ''CountTSQLEndpoints'', ''0'', 0');
END
    ELSE
    BEGIN
    exec('INSERT INTO #FeaturesEnabled SELECT ''CountTSQLEndpoints'', ''0'', 0');
END
END CATCH

/* Collect permissions which are unsupported in CloudSQL SQL Server */
BEGIN
    BEGIN TRY
            exec('INSERT INTO #FeaturesEnabled
                SELECT
                    tmp.permission_name,
					CASE WHEN count(1) > 0 THEN 1 ELSE 0 END,
                    count(1)
                FROM (
                    SELECT
                        pr.name,
                        pr.type,
                        pr.type_desc,
                        p.permission_name,
                        p.type AS permission_type
                    FROM
                        sys.server_permissions p
                        INNER JOIN sys.server_principals pr ON p.grantee_principal_id = pr.principal_id
                    WHERE
                        pr.name NOT LIKE ''NT SERVICE\%''
                        AND name NOT LIKE ''##MS_%##''
                        AND pr.is_fixed_role <> 1
                        AND p.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'',
                        ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'',
                        ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'',
                        ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'',
                        ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')
					UNION ALL
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
                        AND name NOT LIKE ''##MS_%##''
                        AND pr.is_fixed_role <> 1
                        AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'',
                        ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'',
                        ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'',
                        ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'',
                        ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')

                    ) tmp
                GROUP BY
                    tmp.permission_name');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            BEGIN TRY
                    exec('INSERT INTO #FeaturesEnabled
                        SELECT
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
                                INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
                            WHERE
                                pr.name NOT LIKE ''NT SERVICE\%''
                                AND name NOT LIKE ''##MS_%##''
                                AND pr.is_fixed_role <> 1
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
                    exec('
                        INSERT INTO #FeaturesEnabled values (''ADMINISTER BULK OPERATIONS'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER ANY CREDENTIAL'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER ANY EVENT NOTIFICATION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER ANY EVENT SESSION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER RESOURCES'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER SETTINGS'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''AUTHENTICATE SERVER'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CONTROL SERVER'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE ASSEMBLY'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE DDL EVENT NOTIFICATION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE ENDPOINT'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE TRACE EVENT NOTIFICATION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''EXTERNAL ACCESS ASSEMBLY'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''SHUTDOWN'',''0'',0);
                    ');
            END CATCH
    END CATCH
END

--Service Broker tasks
DECLARE @ServBrokerTasksUsed as INT, @IS_ServBrokerTasksUsed as NVARCHAR(4);
select @ServBrokerTasksUsed = count(*)
from sys.dm_broker_activated_tasks;
IF @ServBrokerTasksUsed > 0 SET @IS_ServBrokerTasksUsed = '1'  ELSE  SET @IS_ServBrokerTasksUsed = '0' ;
INSERT INTO #FeaturesEnabled
VALUES
    (
        'Service Broker Tasks Used', @IS_ServBrokerTasksUsed, ISNULL(@ServBrokerTasksUsed,0) );

--External Assemblies
IF @CLOUDTYPE = 'AZURE'
BEGIN
    INSERT INTO #FeaturesEnabled
    VALUES
        (
            'External Assemblies Used', '0', 0);
END
ELSE
BEGIN
    DECLARE @ExternalAssembliesUsed as INT, @IS_ExternalAssembliesUsed as NVARCHAR(4);
    select @ExternalAssembliesUsed = COUNT(*)
    from sys.server_permissions
    where permission_name = 'External access assembly' and state='G';
    IF @ExternalAssembliesUsed > 0 SET @IS_ExternalAssembliesUsed = '1'  ELSE  SET @IS_ExternalAssembliesUsed = '0' ;
    INSERT INTO #FeaturesEnabled
    VALUES
        (
            'External Assemblies Used', @IS_ExternalAssembliesUsed, ISNULL(@ExternalAssembliesUsed,0) );
END

--CLR Enabled
BEGIN
    exec('INSERT INTO #FeaturesEnabled
        SELECT ''IsCLREnabled'',
        CONVERT(NVARCHAR(255), value_in_use),
        CONVERT(int, value_in_use)
        FROM sys.configurations
        WHERE name = ''clr enabled''');
END

--Linked Servers
IF @CLOUDTYPE = 'AZURE'
BEGIN
    INSERT INTO #FeaturesEnabled
    VALUES
        (
            'IsLinkedServersUsed', '0', 0);
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabled
    SELECT ''IsLinkedServersUsed'',
            count(*),
            count(*)
    FROM sys.servers
    WHERE is_linked = 1');
END

--Policy based management
BEGIN TRY
    exec('DECLARE @PoliciesEnabled_value as INT, @IS_PoliciesEnabled as NVARCHAR(4);
        SELECT @PoliciesEnabled_value = count(*) FROM msdb.dbo.syspolicy_policies where is_enabled =1;
	        IF @PoliciesEnabled_value > 0 SET @IS_PoliciesEnabled = ''1''  ELSE  SET @IS_PoliciesEnabled = ''0'' ;
	        INSERT INTO #FeaturesEnabled VALUES (
		        ''Policy-Based Management'', @IS_PoliciesEnabled, ISNULL(@PoliciesEnabled_value,0) );');
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 40515 AND ERROR_SEVERITY() = 15 AND ERROR_STATE() = 1
    exec('INSERT INTO #FeaturesEnabled VALUES (''Policy-Based Management'', ''0'', 0)')
END CATCH

/* Certain clouds do not allow access to certain tables so we need to catch the table does not exist error and default the setting */
BEGIN
    BEGIN TRY
            exec('INSERT INTO #FeaturesEnabled SELECT ''IsBufferPoolExtensionEnabled'',
                  CASE
                    WHEN state = 0 THEN ''0''
                    WHEN state = 1 THEN ''0''
                    WHEN state = 2 THEN ''1''
                    WHEN state = 3 THEN ''1''
                    WHEN state = 4 THEN ''1''
                    WHEN state = 5 THEN ''1''
                    ELSE ''0''
                  END,
                  CASE WHEN state > 0 THEN 1 ELSE 0 END
                  FROM sys.dm_os_buffer_pool_extension_configuration /* SQL Server 2014 (13.x) above */');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
                exec('INSERT INTO #FeaturesEnabled SELECT ''IsBufferPoolExtensionEnabled'', ''0'', 0 /* SQL Server 2014 (13.x) below */');
    END CATCH
END

SELECT
    '"' + @PKEY + '"' as PKEY,
    '"' + CONVERT(NVARCHAR(MAX), f.Features) + '"' as Features,
    '"' + CONVERT(NVARCHAR(MAX), f.Is_EnabledOrUsed) + '"' as Is_EnabledOrUsed,
    '"' + CONVERT(NVARCHAR(MAX), f.Count) + '"' as Count ,
    '"' + @DMA_SOURCE_ID + '"' as dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' as dma_manual_id
FROM #FeaturesEnabled f;

IF OBJECT_ID('tempdb..#FeaturesEnabled') IS NOT NULL
   DROP TABLE #FeaturesEnabled;

IF OBJECT_ID('tempdb..#myPerms') IS NOT NULL
   DROP TABLE #myPerms;
