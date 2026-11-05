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
DECLARE @TABLE_PERMISSION_COUNT AS BIGINT
DECLARE @ROW_COUNT_VAR AS BIGINT
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
    Features NVARCHAR(255),
    Is_EnabledOrUsed NVARCHAR(255),
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
SELECT @TABLE_PERMISSION_COUNT = COUNT_BIG(*)
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
                    WHEN dqs_count > 0 THEN ''1''
                    ELSE ''0''
                END AS Is_EnabledOrUsed,
                dqs_count as Count
            from dqs_service');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 229
            exec('
            INSERT INTO #FeaturesEnabled
                SELECT
                    ''DATA QUALITY SERVICES'' as Features,
                    ''0'' as Is_EnabledOrUsed,
                    ''0'' as Count');
        ELSE IF ERROR_NUMBER() = 208
             exec('
            INSERT INTO #FeaturesEnabled
                SELECT
                    ''DATA QUALITY SERVICES'' as Features,
                    ''0'' as Is_EnabledOrUsed,
                    ''0'' as Count');
        ELSE
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
IF @PRODUCT_VERSION >= 15 AND @CLOUDTYPE <> 'AZURE' AND OBJECT_ID('sys.server_memory_optimized_hybrid_buffer_pool_configuration') IS NOT NULL
BEGIN
    BEGIN TRY
        exec('
            IF EXISTS (SELECT 1 FROM sys.server_memory_optimized_hybrid_buffer_pool_configuration)
            BEGIN
                INSERT INTO #FeaturesEnabled
                SELECT ''IsHybridBufferPoolEnabled'',
                    COALESCE(CONVERT(NVARCHAR(255), is_enabled), ''0''),
                    CASE WHEN is_enabled > 0 THEN 1 ELSE 0 END
                FROM sys.server_memory_optimized_hybrid_buffer_pool_configuration;
            END
            ELSE
            BEGIN
                INSERT INTO #FeaturesEnabled VALUES (''IsHybridBufferPoolEnabled'', ''0'', 0);
            END
        ');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabled VALUES (''IsHybridBufferPoolEnabled'', ''0'', 0)');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabled
        SELECT
        ''IsHybridBufferPoolEnabled'',
        ''0'',
        0
        /* Earlier than SQL Server 2019 (15.x) versions or Azure SQL */');
END;

--log shipping enabled
SELECT @TABLE_PERMISSION_COUNT = COUNT_BIG(*)
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
            WHEN COUNT_BIG(p.permission_name) > 0 THEN '1'
            ELSE '0'
        END,
    CONVERT(bigint,COUNT_BIG(p.permission_name))
FROM fn_my_permissions(NULL, 'SERVER') p
WHERE permission_name like '%ADMINISTER BULK OPERATIONS%';

-- CountServiceBrokerEndpoints
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
            SELECT
                ''CountServiceBrokerEndpoints'',
                CASE
                    WHEN COUNT_BIG(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(bigint, COUNT_BIG(*))
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
                    WHEN COUNT_BIG(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(BIGINT, COUNT_BIG(*))
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
                    SUBSTRING(tmp.permission_name,1,254),
					CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END,
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
                        p.state IN (''G'', ''W'')
                        AND pr.name NOT LIKE ''NT SERVICE\%''
                        AND pr.name NOT LIKE ''NT AUTHORITY\%''
                        AND pr.name NOT LIKE ''##MS_%##''
                        AND pr.name NOT IN (''sa'', ''public'')
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
                        CASE
                            WHEN dp.permission_name = ''ADMINISTER DATABASE BULK OPERATIONS'' THEN ''ADMINISTER BULK OPERATIONS''
                            ELSE dp.permission_name
                        END AS permission_name,
                        dp.type AS permission_type
                    FROM
                        sys.database_permissions dp
                        INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
                    WHERE
                        dp.state IN (''G'', ''W'')
                        AND pr.name NOT LIKE ''NT SERVICE\%''
                        AND pr.name NOT LIKE ''NT AUTHORITY\%''
                        AND pr.name NOT LIKE ''##MS_%##''
                        AND pr.name NOT IN (''dbo'', ''guest'', ''INFORMATION_SCHEMA'', ''sys'', ''public'')
                        AND pr.is_fixed_role <> 1
                        AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ADMINISTER DATABASE BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'',
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
                            SUBSTRING(tmp.permission_name,1,254),
                            CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END,
                            count(1)
                        FROM (
                            SELECT
                                pr.name,
                                pr.type,
                                pr.type_desc,
                                CASE
                                    WHEN dp.permission_name = ''ADMINISTER DATABASE BULK OPERATIONS'' THEN ''ADMINISTER BULK OPERATIONS''
                                    ELSE dp.permission_name
                                END AS permission_name,
                                dp.type AS permission_type
                            FROM
                                sys.database_permissions dp
                                INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
                            WHERE
                                dp.state IN (''G'', ''W'')
                                AND pr.name NOT LIKE ''NT SERVICE\%''
                                AND pr.name NOT LIKE ''NT AUTHORITY\%''
                                AND pr.name NOT LIKE ''##MS_%##''
                                AND pr.name NOT IN (''dbo'', ''guest'', ''INFORMATION_SCHEMA'', ''sys'', ''public'')
                                AND pr.is_fixed_role <> 1
                                AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ADMINISTER DATABASE BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'',
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
            CONVERT(NVARCHAR(255), COUNT_BIG(*)),
            CONVERT(NVARCHAR(255), COUNT_BIG(*))
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

-- Performance Data Collector Check
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'msdb' AND HAS_DBACCESS('msdb') = 1)
   AND OBJECT_ID('msdb.dbo.syscollector_collection_sets') IS NOT NULL
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''Performance Data Collector'',
                     CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                     COUNT(*)
              FROM msdb.dbo.syscollector_collection_sets
              WHERE is_running = 1');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('Performance Data Collector', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('Performance Data Collector', '0', 0);
END;

-- Contained Availability Groups Check (SQL Server 2022+)
IF @PRODUCT_VERSION >= 16
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''ContainedAGCount'',
                     CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                     COUNT(*)
              FROM sys.availability_groups
              WHERE is_contained = 1');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('ContainedAGCount', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('ContainedAGCount', '0', 0);
END;

-- Integrated Acceleration and Offloading Check (SQL Server 2022+)
IF @PRODUCT_VERSION >= 16
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''IntegratedAccelerationEnabled'',
                     CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                     COUNT(*)
              FROM sys.dm_server_accelerator_status
              WHERE ISNULL(mode, 0) > 0 OR ISNULL(config_in_use, 0) > 0');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('IntegratedAccelerationEnabled', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('IntegratedAccelerationEnabled', '0', 0);
END;

-- Link to Azure SQL Managed Instance (Distributed Availability Groups)
IF @PRODUCT_VERSION >= 13
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''AzureSQLMILinkActive'',
                     CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                     COUNT(*)
              FROM sys.availability_groups
              WHERE is_distributed = 1');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('AzureSQLMILinkActive', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('AzureSQLMILinkActive', '0', 0);
END;

-- Azure DevOps Server / TFS Hosting Check
BEGIN TRY
    INSERT INTO #FeaturesEnabled
    SELECT
        'AzureDevOpsServerHost',
        CASE WHEN COUNT(*) > 0 THEN '1' ELSE '0' END,
        COUNT(*)
    FROM sys.databases
    WHERE name IN ('Tfs_Configuration', 'AzureDevOps_Configuration');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('AzureDevOpsServerHost', '0', 0);
END CATCH;

-- External Languages Registered Check (SQL Server 2019+)
IF @PRODUCT_VERSION >= 15
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''ExternalLanguagesRegistered'',
                     CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                     COUNT(*)
              FROM sys.external_languages el
              LEFT JOIN sys.external_language_files elf
                  ON el.external_language_id = elf.external_language_id
              WHERE el.principal_id <> 4 OR elf.content IS NOT NULL');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('ExternalLanguagesRegistered', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('ExternalLanguagesRegistered', '0', 0);
END;

-- Backups to Azure Blob Storage & Object Storage
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''BackupsToAzureBlobStorage'',
                 CASE WHEN COUNT(1) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(1)
          FROM msdb.dbo.backupmediafamily
          WHERE physical_device_name LIKE ''%blob.core.windows.net%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('BackupsToAzureBlobStorage', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''BackupsToObjectStorage'',
                 CASE WHEN COUNT(1) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(1)
          FROM msdb.dbo.backupmediafamily
          WHERE physical_device_name LIKE ''%s3://%''
             OR physical_device_name LIKE ''%blob.core.windows.net%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('BackupsToObjectStorage', '0', 0);
END CATCH;

-- MS-TDS 8.0 Protocol and TLS 1.3
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsTDS80Used'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM sys.dm_exec_connections
          WHERE sys.fn_varbintohexstr(protocol_version) LIKE ''0x8%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsTDS80Used', '0', 0);
END CATCH;

-- In-Memory OLTP Support for Database Snapshots
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''in-memory-oltp'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM sys.databases snap
          WHERE snap.source_database_id IS NOT NULL
            AND EXISTS (
                SELECT 1
                FROM sys.master_files mf
                WHERE mf.database_id = snap.source_database_id
                  AND mf.type = 2
            )');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('in-memory-oltp', '0', 0);
END CATCH;

-- Dedicated Administrator Connection (DAC)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsDACEnabled'',
                 CASE WHEN (
                     ISNULL((SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = ''remote admin connections''), 0)
                     + ISNULL((SELECT COUNT(*) FROM sys.dm_exec_connections c INNER JOIN sys.endpoints e ON c.endpoint_id = e.endpoint_id WHERE e.is_admin_endpoint = 1), 0)
                 ) > 0 THEN ''1'' ELSE ''0'' END,
                 ISNULL((SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = ''remote admin connections''), 0)
                 + ISNULL((SELECT COUNT(*) FROM sys.dm_exec_connections c INNER JOIN sys.endpoints e ON c.endpoint_id = e.endpoint_id WHERE e.is_admin_endpoint = 1), 0)');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsDACEnabled', '0', 0);
END CATCH;

-- Distributed Transaction Coordinator (MSDTC)
BEGIN TRY
    IF @PRODUCT_VERSION >= 13 AND COL_LENGTH('sys.availability_groups', 'dtc_support') IS NOT NULL
    BEGIN
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''IsDTCInUse'',
                     CASE WHEN (
                         ISNULL((SELECT COUNT(*) FROM sys.availability_groups WHERE ISNULL(dtc_support, 0) > 0), 0)
                         + ISNULL((SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = ''remote proc trans''), 0)
                         + ISNULL((SELECT COUNT(*) FROM sys.dm_tran_active_transactions WHERE transaction_type = 4 OR ISNULL(dtc_state, 0) > 0), 0)
                     ) > 0 THEN ''1'' ELSE ''0'' END,
                     ISNULL((SELECT COUNT(*) FROM sys.availability_groups WHERE ISNULL(dtc_support, 0) > 0), 0)
                     + ISNULL((SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = ''remote proc trans''), 0)
                     + ISNULL((SELECT COUNT(*) FROM sys.dm_tran_active_transactions WHERE transaction_type = 4 OR ISNULL(dtc_state, 0) > 0), 0)');
    END
    ELSE
    BEGIN
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''IsDTCInUse'',
                     CASE WHEN (
                         ISNULL((SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = ''remote proc trans''), 0)
                         + ISNULL((SELECT COUNT(*) FROM sys.dm_tran_active_transactions WHERE transaction_type = 4 OR ISNULL(dtc_state, 0) > 0), 0)
                     ) > 0 THEN ''1'' ELSE ''0'' END,
                     ISNULL((SELECT CONVERT(INT, value_in_use) FROM sys.configurations WHERE name = ''remote proc trans''), 0)
                     + ISNULL((SELECT COUNT(*) FROM sys.dm_tran_active_transactions WHERE transaction_type = 4 OR ISNULL(dtc_state, 0) > 0), 0)');
    END
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsDTCInUse', '0', 0);
END CATCH;

-- Persistent Memory (PMEM)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsPMEMEnabled'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM sys.dm_os_loaded_modules
          WHERE LOWER(name) LIKE ''%pmem%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsPMEMEnabled', '0', 0);
END CATCH;

-- Hybrid Buffer Pool with Direct Write (SQL Server 2022+)
IF @PRODUCT_VERSION >= 16 AND COL_LENGTH('sys.server_memory_optimized_hybrid_buffer_pool_configuration', 'is_direct_write_enabled') IS NOT NULL
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''IsHybridBufferPoolDirectWriteEnabled'',
                     CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                     COUNT(*)
              FROM sys.server_memory_optimized_hybrid_buffer_pool_configuration
              WHERE ISNULL(is_enabled, 0) = 1
                AND ISNULL(is_direct_write_enabled, 0) = 1');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('IsHybridBufferPoolDirectWriteEnabled', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('IsHybridBufferPoolDirectWriteEnabled', '0', 0);
END;

-- Multi-Write Replication (merge publishers only; sys.databases has no is_merge_subscribed column,
-- peer-to-peer and updatable subscriptions are reported per database by dbServerFeaturesDatabaseLevel.sql)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsMultiWriteReplicationUsed'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM sys.databases
          WHERE is_merge_published = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsMultiWriteReplicationUsed', '0', 0);
END CATCH;

-- Support for PFX Certificates and Cryptographic Improvements (Server-Level)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''UserCertificatesUsed'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM master.sys.certificates
          WHERE name NOT LIKE ''##MS_%''
            AND pvt_key_encryption_type <> ''NA''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('UserCertificatesUsed', '0', 0);
END CATCH;

-- RESTORE Operation Usage (SQL Agent Jobs / Non-Fixed Server Principals)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''RESTORE'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM msdb.dbo.sysjobsteps js
          INNER JOIN msdb.dbo.sysjobs j ON js.job_id = j.job_id
          WHERE j.enabled = 1
            AND js.subsystem = ''TSQL''
            AND (
                UPPER(js.command) LIKE ''%RESTORE DATABASE%''
                OR UPPER(js.command) LIKE ''%RESTORE LOG%''
                OR UPPER(js.command) LIKE ''%RESTORE HEADERONLY%''
                OR UPPER(js.command) LIKE ''%RESTORE FILELISTONLY%''
            )');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('RESTORE', '0', 0);
END CATCH;

/* ------------------------------------------------------------------------------------------------
   Coverage-gap rows (DMA 2.0 parity). Naming convention shared with the DMA 2.0 collector:
   a feature name starting with "Is" carries 0/1 in Is_EnabledOrUsed, a plain noun carries the
   count in both Is_EnabledOrUsed and Count, and a text-valued row carries the value in
   Is_EnabledOrUsed with Count = 0. Every block falls back to ('0', 0) when the DMV is absent
   or not readable so the script never fails as a whole.
   ------------------------------------------------------------------------------------------------ */

-- Policy-Based Management (DMA 2.0 row name; the legacy 'Policy-Based Management' row above is kept)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsPolicyBasedManagementEnabled'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM msdb.dbo.syspolicy_policies
          WHERE is_enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsPolicyBasedManagementEnabled', '0', 0);
END CATCH;

-- Extended Events sessions (user-defined only)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ExtendedEventSessions'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_event_sessions
          WHERE name NOT IN (''system_health'', ''AlwaysOn_health'', ''telemetry_xevents'', ''sp_server_diagnostics session'')');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ExtendedEventSessions', '0', 0);
END CATCH;

-- Extended Events sessions writing to a local file target
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ExtendedEventSessionsWithFileTarget'',
                 CONVERT(NVARCHAR(255), COUNT(DISTINCT s.event_session_id)),
                 COUNT(DISTINCT s.event_session_id)
          FROM sys.server_event_sessions s
          INNER JOIN sys.server_event_session_targets t ON s.event_session_id = t.event_session_id
          WHERE t.name IN (''event_file'', ''asynchronous_file_target'')
            AND s.name NOT IN (''system_health'', ''AlwaysOn_health'', ''telemetry_xevents'', ''sp_server_diagnostics session'')');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ExtendedEventSessionsWithFileTarget', '0', 0);
END CATCH;

-- Server audit specifications (enabled)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ServerAuditSpecifications'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_audit_specifications
          WHERE is_state_enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ServerAuditSpecifications', '0', 0);
END CATCH;

-- Server audits by destination (enabled): file, Windows Security log, Windows Application log
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ServerAuditsToFile'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_audits
          WHERE type = ''FL'' AND is_state_enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ServerAuditsToFile', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ServerAuditsToSecurityLog'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_audits
          WHERE type = ''SL'' AND is_state_enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ServerAuditsToSecurityLog', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ServerAuditsToApplicationLog'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_audits
          WHERE type = ''AL'' AND is_state_enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ServerAuditsToApplicationLog', '0', 0);
END CATCH;

-- Startup procedures registered with sp_procoption (master only)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''StartupProcedures'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM master.sys.procedures
          WHERE is_auto_executed = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('StartupProcedures', '0', 0);
END CATCH;

-- Login inventory by type (no names are emitted)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''SqlLogins'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_principals
          WHERE type = ''S''
            AND name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('SqlLogins', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''WindowsLogins'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_principals
          WHERE type = ''U''
            AND name NOT LIKE ''NT SERVICE\%''
            AND name NOT LIKE ''NT AUTHORITY\%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('WindowsLogins', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''WindowsGroupLogins'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_principals
          WHERE type = ''G''
            AND name NOT LIKE ''NT SERVICE\%''
            AND name NOT LIKE ''NT AUTHORITY\%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('WindowsGroupLogins', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''CertificateMappedLogins'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_principals
          WHERE type IN (''C'', ''K'')
            AND name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('CertificateMappedLogins', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''DisabledLogins'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_principals
          WHERE type IN (''S'', ''U'', ''G'', ''C'', ''K'')
            AND is_disabled = 1
            AND name NOT LIKE ''##MS_%''
            AND name NOT LIKE ''NT SERVICE\%''
            AND name NOT LIKE ''NT AUTHORITY\%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('DisabledLogins', '0', 0);
END CATCH;

-- Fixed server role membership counts (service accounts excluded, sa included)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''SysadminMembers'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_role_members rm
          INNER JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
          INNER JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
          WHERE r.name = ''sysadmin''
            AND m.name NOT LIKE ''NT SERVICE\%''
            AND m.name NOT LIKE ''NT AUTHORITY\%''
            AND m.name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('SysadminMembers', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''SecurityadminMembers'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_role_members rm
          INNER JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
          INNER JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
          WHERE r.name = ''securityadmin''
            AND m.name NOT LIKE ''NT SERVICE\%''
            AND m.name NOT LIKE ''NT AUTHORITY\%''
            AND m.name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('SecurityadminMembers', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ServeradminMembers'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.server_role_members rm
          INNER JOIN sys.server_principals r ON rm.role_principal_id = r.principal_id
          INNER JOIN sys.server_principals m ON rm.member_principal_id = m.principal_id
          WHERE r.name = ''serveradmin''
            AND m.name NOT LIKE ''NT SERVICE\%''
            AND m.name NOT LIKE ''NT AUTHORITY\%''
            AND m.name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ServeradminMembers', '0', 0);
END CATCH;

-- User-defined server roles (SQL Server 2012 (11.x) and later; is_fixed_role does not exist before)
IF @PRODUCT_VERSION >= 11
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabled
              SELECT ''CustomServerRoles'',
                     CONVERT(NVARCHAR(255), COUNT(*)),
                     COUNT(*)
              FROM sys.server_principals
              WHERE type = ''R''
                AND is_fixed_role = 0
                AND name <> ''public''');
    END TRY
    BEGIN CATCH
        INSERT INTO #FeaturesEnabled VALUES ('CustomServerRoles', '0', 0);
    END CATCH
END
ELSE
BEGIN
    INSERT INTO #FeaturesEnabled VALUES ('CustomServerRoles', '0', 0);
END;

-- SQL Agent operators, alerts, proxies and jobs with notifications (Database Mail / OS dependencies)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''AgentOperators'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.sysoperators
          WHERE enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('AgentOperators', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''AgentAlerts'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.sysalerts
          WHERE enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('AgentAlerts', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''AgentProxies'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.sysproxies
          WHERE enabled = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('AgentProxies', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''AgentJobsWithNotification'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.sysjobs
          WHERE notify_level_email > 0
             OR notify_level_page > 0
             OR notify_level_netsend > 0');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('AgentJobsWithNotification', '0', 0);
END CATCH;

-- Maintenance plans and SSIS packages stored in msdb (packagetype 6 = maintenance plan internals)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''MaintenancePlans'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.sysmaintplan_plans');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('MaintenancePlans', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''SsisPackagesInMsdb'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.sysssispackages
          WHERE packagetype <> 6');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('SsisPackagesInMsdb', '0', 0);
END CATCH;

-- SSIS catalog database present (excluded from per-database collection, so recorded here)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsSsisdbPresent'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM sys.databases
          WHERE name = ''SSISDB''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsSsisdbPresent', '0', 0);
END CATCH;

-- Full-Text Search: installed component and running filter daemon launcher (engine-side view;
-- componentsInstalled.sql reports the Windows service inventory for SSRS/SSAS/SSIS/Browser)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsFullTextInstalled'',
                 CONVERT(NVARCHAR(255), ISNULL(CONVERT(INT, SERVERPROPERTY(''IsFullTextInstalled'')), 0)),
                 ISNULL(CONVERT(INT, SERVERPROPERTY(''IsFullTextInstalled'')), 0)');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsFullTextInstalled', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''IsFullTextDaemonRunning'',
                 CASE WHEN COUNT(*) > 0 THEN ''1'' ELSE ''0'' END,
                 COUNT(*)
          FROM sys.dm_server_services
          WHERE servicename LIKE ''SQL Full-text Filter Daemon Launcher%''
            AND status = 4 /* SQL Server 2008 R2 SP1 and later */');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('IsFullTextDaemonRunning', '0', 0);
END CATCH;

-- Server collation (text value carried in Is_EnabledOrUsed)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ServerCollation'',
                 ISNULL(CONVERT(NVARCHAR(255), SERVERPROPERTY(''Collation'')), ''0''),
                 0');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ServerCollation', '0', 0);
END CATCH;

-- Encryption key inventory in master and EKM providers
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''SymmetricKeysInMaster'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM master.sys.symmetric_keys
          WHERE name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('SymmetricKeysInMaster', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''AsymmetricKeysInMaster'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM master.sys.asymmetric_keys');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('AsymmetricKeysInMaster', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''EkmProviders'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.cryptographic_providers');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('EkmProviders', '0', 0);
END CATCH;

-- Replication roles by database (sys.databases carries no merge-subscriber flag; that role is
-- reported per database by dbServerFeaturesDatabaseLevel.sql as IsMergeSubscribed)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ReplicationPublisherDatabases'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.databases
          WHERE is_published = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ReplicationPublisherDatabases', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ReplicationSubscriberDatabases'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.databases
          WHERE is_subscribed = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ReplicationSubscriberDatabases', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ReplicationDistributorDatabases'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.databases
          WHERE is_distributor = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ReplicationDistributorDatabases', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ReplicationMergePublisherDatabases'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.databases
          WHERE is_merge_published = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ReplicationMergePublisherDatabases', '0', 0);
END CATCH;

-- Replication topology peers from sys.servers (counts only; no server names are emitted).
-- RemoteDistributor counts distributor entries whose data source is not this instance.
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''RemoteDistributor'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.servers
          WHERE is_distributor = 1
            AND UPPER(ISNULL(data_source, '''')) <> UPPER(CONVERT(NVARCHAR(128), @@SERVERNAME))
            AND UPPER(ISNULL(data_source, '''')) <> UPPER(CONVERT(NVARCHAR(128), SERVERPROPERTY(''ServerName'')))');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('RemoteDistributor', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ReplicationSubscriberServers'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.servers
          WHERE is_subscriber = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ReplicationSubscriberServers', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''ReplicationPublisherServers'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM sys.servers
          WHERE is_publisher = 1');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('ReplicationPublisherServers', '0', 0);
END CATCH;

-- Distributor metadata in msdb (populated only when this instance hosts a distributor)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''DistributionPublishers'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.MSdistpublishers');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('DistributionPublishers', '0', 0);
END CATCH;

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabled
          SELECT ''DistributionDatabases'',
                 CONVERT(NVARCHAR(255), COUNT(*)),
                 COUNT(*)
          FROM msdb.dbo.MSdistributiondbs');
END TRY
BEGIN CATCH
    INSERT INTO #FeaturesEnabled VALUES ('DistributionDatabases', '0', 0);
END CATCH;

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
