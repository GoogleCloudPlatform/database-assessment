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

/* sys.dm_os_host_info - Applies to: SQL Server 2017 (14.x) and later */
SET NOCOUNT ON;
SET LANGUAGE us_english;
DECLARE @PKEY AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @TABLE_PERMISSION_COUNT AS INTEGER
DECLARE @MACHINENAME AS VARCHAR(256)
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE'
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF CHARINDEX('\', @@SERVERNAME)-1 = -1
  SELECT @MACHINENAME = UPPER(@@SERVERNAME)
ELSE
  SELECT @MACHINENAME = UPPER(SUBSTRING(CONVERT(nvarchar, @@SERVERNAME),1,CHARINDEX('\', CONVERT(nvarchar, @@SERVERNAME))-1))

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;

CREATE TABLE #serverProperties(
    property_name nvarchar(256)
    ,property_value nvarchar(1024)
);

/* need to record table permissions in order to determine if we can run certain serverprops queryies
    as some tables are not available in managed instances 
*/
IF OBJECT_ID('tempdb..#myPerms') IS NOT NULL  
   DROP TABLE #myPerms;

CREATE TABLE #myPerms (
    entity_name nvarchar(255), 
    subentity_name nvarchar(255), 
    permission_name nvarchar(255)
);

INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.sysmail_server', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.sysmail_profile', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.sysmail_profileaccount', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.sysmail_account', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.log_shipping_secondary_databases', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.log_shipping_primary_databases', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.sysmaintplan_subplans', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';
INSERT INTO #myPerms SELECT * FROM fn_my_permissions('msdb.dbo.sysjobs', 'OBJECT') WHERE permission_name = 'SELECT' and subentity_name ='';

INSERT INTO #serverProperties
SELECT 'BuildClrVersion' AS Property, CONVERT(nvarchar, SERVERPROPERTY('BuildClrVersion')) AS Value
UNION ALL
SELECT 'Collation', CONVERT(nvarchar, SERVERPROPERTY('Collation'))
UNION ALL
SELECT 'CollationID', CONVERT(nvarchar, SERVERPROPERTY('CollationID'))
UNION ALL
SELECT 'ComparisonStyle', CONVERT(nvarchar, SERVERPROPERTY('ComparisonStyle'))
UNION ALL
SELECT 'Edition', CONVERT(nvarchar, SERVERPROPERTY('Edition'))
UNION ALL
SELECT 'EditionID', CONVERT(nvarchar, SERVERPROPERTY('EditionID'))
UNION ALL
SELECT 'EngineEdition', CONVERT(nvarchar, SERVERPROPERTY('EngineEdition'))
UNION ALL
SELECT 'HadrManagerStatus', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('HadrManagerStatus')), '0')
UNION ALL
SELECT 'IsAdvancedAnalyticsInstalled', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('IsAdvancedAnalyticsInstalled')), '0')
UNION ALL
SELECT 'IsClustered', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('IsClustered')), '0')
UNION ALL
SELECT 'IsFullTextInstalled', CONVERT(nvarchar, SERVERPROPERTY('IsFullTextInstalled'))
UNION ALL
SELECT 'IsHadrEnabled', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('IsHadrEnabled')), '0')
UNION ALL
SELECT 'IsIntegratedSecurityOnly', CONVERT(nvarchar, SERVERPROPERTY('IsIntegratedSecurityOnly'))
UNION ALL
SELECT 'IsLocalDB', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('IsLocalDB')), '0')
UNION ALL
SELECT 'IsPolyBaseInstalled',  COALESCE(CONVERT(nvarchar, SERVERPROPERTY('IsPolyBaseInstalled')), '0')
UNION ALL
SELECT 'IsSingleUser', CONVERT(nvarchar, SERVERPROPERTY('IsSingleUser'))
UNION ALL
SELECT 'IsXTPSupported', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('IsXTPSupported')), '0')
UNION ALL
SELECT 'LCID', CONVERT(nvarchar, SERVERPROPERTY('LCID'))
UNION ALL
SELECT 'LicenseType', CONVERT(nvarchar, SERVERPROPERTY('LicenseType'))
UNION ALL
SELECT 'MachineName', @MACHINENAME
UNION ALL
SELECT 'NumLicenses', CONVERT(nvarchar, SERVERPROPERTY('NumLicenses'))
UNION ALL
SELECT 'ProcessID', CONVERT(nvarchar, SERVERPROPERTY('ProcessID'))
UNION ALL
SELECT 'ProductBuild', CONVERT(nvarchar, SERVERPROPERTY('ProductBuild'))
UNION ALL
SELECT 'ProductBuildType', CONVERT(nvarchar, SERVERPROPERTY('ProductBuildType'))
UNION ALL
SELECT 'ProductLevel', CONVERT(nvarchar, SERVERPROPERTY('ProductLevel'))
UNION ALL
SELECT 'ProductMajorVersion', CONVERT(nvarchar, SERVERPROPERTY('ProductMajorVersion'))
UNION ALL
SELECT 'ProductMinorVersion', CONVERT(nvarchar, SERVERPROPERTY('ProductMinorVersion'))
UNION ALL
SELECT 'ProductUpdateLevel', CONVERT(nvarchar, SERVERPROPERTY('ProductUpdateLevel'))
UNION ALL
SELECT 'ProductUpdateReference', CONVERT(nvarchar, SERVERPROPERTY('ProductUpdateReference'))
UNION ALL
SELECT 'ProductVersion', CONVERT(nvarchar, SERVERPROPERTY('ProductVersion'))
UNION ALL
SELECT 'ResourceLastUpdateDateTime', LTRIM(RTRIM(REPLACE(CONVERT(nvarchar, SERVERPROPERTY('ResourceLastUpdateDateTime')),'  ',' ')))
UNION ALL
SELECT 'ResourceVersion', CONVERT(nvarchar, SERVERPROPERTY('ResourceVersion'))
UNION ALL
SELECT 'ServerName', CONVERT(nvarchar, SERVERPROPERTY('ServerName'))
UNION ALL
SELECT 'SqlCharSet', CONVERT(nvarchar, SERVERPROPERTY('SqlCharSet'))
UNION ALL
SELECT 'SqlCharSetName', CONVERT(nvarchar, SERVERPROPERTY('SqlCharSetName'))
UNION ALL
SELECT 'SqlSortOrder', CONVERT(nvarchar, SERVERPROPERTY('SqlSortOrder'))
UNION ALL
SELECT 'SqlSortOrderName', CONVERT(nvarchar, SERVERPROPERTY('SqlSortOrderName'))
UNION ALL
SELECT 'FilestreamShareName', COALESCE(CONVERT(nvarchar, SERVERPROPERTY('FilestreamShareName')),'NONE')
UNION ALL
SELECT 'FilestreamConfiguredLevel', CONVERT(nvarchar, SERVERPROPERTY('FilestreamConfiguredLevel'))
UNION ALL
SELECT 'FilestreamEffectiveLevel', CONVERT(nvarchar, SERVERPROPERTY('FilestreamEffectiveLevel'))
UNION ALL
SELECT 'FullVersion', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), ' '), CHAR(10), ' '),1,1024)
UNION ALL
SELECT 'IsResourceGovenorEnabled', CONVERT(varchar, is_enabled) from sys.resource_governor_configuration
UNION ALL
SELECT 'IsTDEInUse', CONVERT(nvarchar, count(*)) from sys.databases where is_encrypted <> 0
UNION ALL
SELECT 'LogicalCpuCount', CONVERT(varchar, cpu_count) from sys.dm_os_sys_info
UNION ALL
SELECT 'PhysicalCpuCount', CONVERT(varchar, (cpu_count/hyperthread_ratio)) from sys.dm_os_sys_info
UNION ALL
SELECT 'SqlServerStartTime', CONVERT(varchar, (sqlserver_start_time)) from sys.dm_os_sys_info
UNION ALL
SELECT 'BULK_INSERT', CONVERT(varchar,count(p.permission_name)) FROM fn_my_permissions(NULL, 'SERVER') p WHERE permission_name like '%ADMINISTER BULK OPERATIONS%';
WITH check_sysadmin_role AS (
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
INSERT INTO #serverProperties 
    SELECT 'sysadmin_role',
    CASE WHEN count(*) > 0
    THEN '1'
    ELSE '0'
	END
FROM
    check_sysadmin_role;
WITH BUFFER_POOL_SIZE AS (
	SELECT database_id AS DatabaseID
		,DB_NAME(database_id) AS DatabaseName
		,COUNT(file_id) * 8 / 1024.0 AS BufferSizeInMB
	FROM sys.dm_os_buffer_descriptors
	GROUP BY DB_NAME(database_id)
		,database_id
)
INSERT INTO #serverProperties
    SELECT 'total_buffer_size_in_mb'
	,SUM(BufferSizeInMB)
FROM BUFFER_POOL_SIZE;

/* Certain clouds do not allow access to certain tables so we need to catch the table does not exist error and default the setting */
IF @CLOUDTYPE = 'AZURE'
BEGIN
    exec('INSERT INTO #serverProperties SELECT ''InstanceName'', CONVERT(nvarchar, COALESCE(SERVERPROPERTY(''InstanceName''),@@SERVERNAME))')
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''IsRpcOutEnabled'', CONVERT(nvarchar, is_rpc_out_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''IsRpcOutEnabled'', ''0''')
    END CATCH
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''IsRemoteProcTransactionPromotionEnabled'', CONVERT(nvarchar, is_remote_proc_transaction_promotion_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''IsRemoteProcTransactionPromotionEnabled'', ''0''')
    END CATCH
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''IsRemoteLoginEnabled'', CONVERT(nvarchar, is_remote_login_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''IsRemoteLoginEnabled'', ''0''')
    END CATCH
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''ServerLevelTriggers'', CONVERT(varchar, count(*)) from sys.server_triggers')
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''ServerLevelTriggers'', ''0''')
    END CATCH
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''CountServiceBrokerEndpoints'', CONVERT(varchar, count(*)) from sys.service_broker_endpoints')
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''CountServiceBrokerEndpoints'', ''0''')
    END CATCH
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', CONVERT(nvarchar, count(*)) from sys.availability_groups where dtc_support is not null /* SQL Server 2016 (13.x) and above */');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', ''0'' /* SQL Server 2016 (13.x) and above */');
    END CATCH
    BEGIN TRY
            exec('INSERT INTO #serverProperties SELECT ''IsBufferPoolExtensionEnabled'', CONVERT(nvarchar, state) FROM sys.dm_os_buffer_pool_extension_configuration /* SQL Server 2014 (13.x) above */');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
                exec('INSERT INTO #serverProperties SELECT ''IsBufferPoolExtensionEnabled'', ''0'' /* SQL Server 2014 (13.x) above */');
    END CATCH
    BEGIN TRY
            exec('INSERT INTO #serverProperties SELECT ''CountTSQLEndpoints'', CONVERT(varchar, count(*)) from sys.tcp_endpoints where endpoint_id > 65535')
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
                exec('INSERT INTO #serverProperties SELECT ''CountTSQLEndpoints'', ''0''')
    END CATCH
    
    exec('INSERT INTO #serverProperties SELECT ''IsHybridBufferPoolEnabled'', CONVERT(nvarchar,is_enabled) from sys.server_memory_optimized_hybrid_buffer_pool_configuration /* SQL Server 2019 (15.x) and later versions */');
    exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', ''Azure VM''');
    exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', ''Linux''');
    exec('INSERT INTO #serverProperties SELECT ''HostRelease'', ''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', ''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'', ''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''IsStretchDatabaseEnabled'', CONVERT(nvarchar, count(*)) FROM sys.remote_data_archive_databases');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryUsedInMB'', CONVERT(nvarchar, committed_kb/1024) FROM sys.dm_os_sys_info');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryTargetInMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info');
    /* Default Memory Usage to SQLServerMemoryTargetInMB for Azure SQL Database because data is not available */
    exec('INSERT INTO #serverProperties SELECT ''TotalOSMemoryMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info')
    exec('INSERT INTO #serverProperties SELECT ''AvailableOSMemoryMB'', CONVERT(varchar, 0)')
    exec('INSERT INTO #serverProperties SELECT ''TotalMemoryInUseIncludingProcessesInMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info')
    exec('INSERT INTO #serverProperties SELECT ''TotalLockedPageAllocInMB'', CONVERT(varchar, 0)')
    exec('INSERT INTO #serverProperties SELECT ''TotalUserVirtualMemoryInMB'', CONVERT(varchar, 0)')
    exec('INSERT INTO #serverProperties SELECT ''MaxConfiguredSQLServerMemoryMB'', CASE WHEN value = maximum THEN ''0'' ELSE CONVERT(varchar, (value)) END from sys.configurations where name = ''max server memory (MB)''')
END
IF @CLOUDTYPE = 'NONE'
BEGIN
    exec('INSERT INTO #serverProperties SELECT ''InstanceName'', CONVERT(nvarchar, COALESCE(SERVERPROPERTY(''InstanceName''),@@ServiceName))')
    exec('INSERT INTO #serverProperties SELECT ''IsRpcOutEnabled'', CONVERT(nvarchar, is_rpc_out_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    exec('INSERT INTO #serverProperties SELECT ''IsRemoteProcTransactionPromotionEnabled'', CONVERT(nvarchar, is_remote_proc_transaction_promotion_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    exec('INSERT INTO #serverProperties SELECT ''IsRemoteLoginEnabled'', CONVERT(nvarchar, is_remote_login_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    exec('INSERT INTO #serverProperties SELECT ''ServerLevelTriggers'', CONVERT(varchar, count(*)) from sys.server_triggers')
    exec('INSERT INTO #serverProperties SELECT ''CountServiceBrokerEndpoints'', CONVERT(varchar, count(*)) from sys.service_broker_endpoints')
    exec('INSERT INTO #serverProperties SELECT ''CountTSQLEndpoints'', CONVERT(varchar, count(*)) from sys.tcp_endpoints where endpoint_id > 65535')
    /* Query Memory usage at OS level */
    exec('INSERT INTO #serverProperties SELECT ''TotalOSMemoryMB'', CONVERT(varchar, (total_physical_memory_kb/1024)) FROM sys.dm_os_sys_memory')
    exec('INSERT INTO #serverProperties SELECT ''AvailableOSMemoryMB'', CONVERT(varchar, (available_physical_memory_kb/1024)) FROM sys.dm_os_sys_memory')
    exec('INSERT INTO #serverProperties SELECT ''TotalMemoryInUseIncludingProcessesInMB'', CONVERT(varchar, (physical_memory_in_use_kb/1024)) FROM sys.dm_os_process_memory')
    exec('INSERT INTO #serverProperties SELECT ''TotalLockedPageAllocInMB'', CONVERT(varchar, (locked_page_allocations_kb/1024)) FROM sys.dm_os_process_memory')
    exec('INSERT INTO #serverProperties SELECT ''TotalUserVirtualMemoryInMB'', CONVERT(varchar, (total_virtual_address_space_kb/1024)) FROM sys.dm_os_process_memory')
    exec('INSERT INTO #serverProperties SELECT ''MaxConfiguredSQLServerMemoryMB'', CASE WHEN value = maximum THEN ''0'' ELSE CONVERT(varchar, (value)) END from sys.configurations where name = ''max server memory (MB)''')
    IF @PRODUCT_VERSION >= 15
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''IsHybridBufferPoolEnabled'', CONVERT(nvarchar,is_enabled) from sys.server_memory_optimized_hybrid_buffer_pool_configuration /* SQL Server 2019 (15.x) and later versions */');
    END;
    IF @PRODUCT_VERSION >= 14
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', SUBSTRING(CONVERT(nvarchar,host_platform),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
    exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', SUBSTRING(CONVERT(nvarchar,host_distribution),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
    exec('INSERT INTO #serverProperties SELECT ''HostRelease'', SUBSTRING(CONVERT(nvarchar,host_release),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
    exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', COALESCE(SUBSTRING(CONVERT(nvarchar,host_service_pack_level),1,1024), ''UNKNOWN'')  FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
    exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',SUBSTRING(CONVERT(nvarchar, os_language_version),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
    END;
    IF @PRODUCT_VERSION >= 11 AND @PRODUCT_VERSION < 14
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', ''Windows'' FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and SQL Server 2012 (11.x)  */');
    exec('INSERT INTO #serverProperties SELECT ''HostRelease'', SUBSTRING(CONVERT(nvarchar,windows_release),1,1024) FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and SQL Server 2012 (11.x)  */');
    exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', COALESCE(SUBSTRING(CONVERT(nvarchar,windows_service_pack_level),1,1024), ''UNKNOWN'') FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and SQL Server 2012 (11.x)  */');
    exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',SUBSTRING(CONVERT(nvarchar, os_language_version),1,1024) FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and SQL Server 2012 (11.x)  */');
    exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), '' ''), CHAR(10), '' ''),1,1024) /* SQL Server 2016 (13.x) and SQL Server 2012 (11.x) */');
    END
    IF @PRODUCT_VERSION < 11
    BEGIN   /* Versions before SQL Server 2012 (11.x)   */
    exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', ''Windows''');
    exec('INSERT INTO #serverProperties SELECT ''HostRelease'', REPLACE(REPLACE(SUBSTRING(@@VERSION,4 + charindex ('' ON '',@@VERSION),LEN(@@VERSION)), CHAR(13), ''''), CHAR(10), '''')');
    exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', COALESCE(SUBSTRING(CONVERT(nvarchar,SERVERPROPERTY(''ProductLevel'')),1,1024), ''UNKNOWN'') ');
    exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), '' ''), CHAR(10), '' ''),1,1024)');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryUsedInMB'', CONVERT(nvarchar, 0) /* Parameter defaulted because its not avaliable in this version */');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryTargetInMB'', CONVERT(nvarchar, 0) /* Parameter defaulted because its not avaliable in this version */');
    END;
    IF @PRODUCT_VERSION >= 13 AND @PRODUCT_VERSION <= 16
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''IsStretchDatabaseEnabled'', CONVERT(nvarchar, count(*)) FROM sys.remote_data_archive_databases /* SQL Server 2016 (13.x) and Up to 2022 */');
    END;
    IF @PRODUCT_VERSION >= 13
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', CONVERT(nvarchar, count(*)) from sys.availability_groups where dtc_support is not null /* SQL Server 2016 (13.x) and above */');
    END;
    IF @PRODUCT_VERSION >= 12
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''IsBufferPoolExtensionEnabled'', CONVERT(nvarchar, state) FROM sys.dm_os_buffer_pool_extension_configuration /* SQL Server 2014 (13.x) above */');
    END;
    IF @PRODUCT_VERSION >= 11
    BEGIN
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryUsedInMB'', CONVERT(nvarchar, committed_kb/1024) FROM sys.dm_os_sys_info /* SQL Server 2012 (11.x) above */');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryTargetInMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info /* SQL Server 2012 (11.x) above */');
    exec('WITH check_filestream AS (
        SELECT
            Name,
            ISNULL ((
                    SELECT
                        1
                    FROM
                        sys.master_files AS mf
                    WHERE
                        mf.database_id = db.database_id
                        AND mf.type = 2),
                    0) AS hasfs
        FROM
            sys.databases AS db
    )
    INSERT INTO #serverProperties SELECT
        ''IsFileStreamEnabled'',
        sum(hasfs)
    FROM
        check_filestream
    /* SQL Server 2012 (11.x) above */');
    END;
END;

/* check the table permissions temp table before we run this query. Otherwise default the value to show that mail is off */
SELECT @TABLE_PERMISSION_COUNT = COUNT(*) FROM #myPerms 
WHERE LOWER(entity_name) in ('dbo.sysmail_profile','dbo.sysmail_profileaccount','dbo.sysmail_account','dbo.sysmail_server') and UPPER(permission_name) = 'SELECT';
IF @TABLE_PERMISSION_COUNT >= 4 AND @CLOUDTYPE = 'NONE'
BEGIN
    BEGIN TRY
    exec('INSERT INTO #serverProperties
    SELECT
        ''IsDbMailEnabled'', CONVERT(nvarchar, count(*))
    FROM
        msdb.dbo.sysmail_profile p
        JOIN msdb.dbo.sysmail_profileaccount pa ON p.profile_id = pa.profile_id
        JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
        JOIN msdb.dbo.sysmail_server s ON a.account_id = s.account_id');
    END TRY
    BEGIN CATCH
    IF ERROR_NUMBER() = 40515 AND ERROR_SEVERITY() = 15 AND ERROR_STATE() = 1
        exec('INSERT INTO #serverProperties
        SELECT
            ''IsDbMailEnabled'', ''0''');
    END CATCH
END;
ELSE
BEGIN
exec('INSERT INTO #serverProperties
SELECT ''IsDbMailEnabled'', CAST(COALESCE(value_in_use,0) as NVARCHAR)  FROM  sys.configurations WHERE name = ''Database Mail XPs''
');
END;
SELECT @TABLE_PERMISSION_COUNT = COUNT(*) FROM #myPerms 
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
INSERT INTO #serverProperties SELECT
    ''IsLogShippingEnabled'', CONVERT(varchar,COALESCE(sum(log_shipping),0))
FROM
    log_shipping_count');
END;
ELSE
BEGIN
exec('INSERT INTO #serverProperties VALUES (''IsLogShippingEnabled'', CONVERT(varchar,0))');
END;
SELECT @TABLE_PERMISSION_COUNT = COUNT(*) FROM #myPerms 
WHERE LOWER(entity_name) in ('dbo.sysmaintplan_subplans','dbo.sysjobs') and UPPER(permission_name) = 'SELECT';
IF @TABLE_PERMISSION_COUNT >= 2
BEGIN
exec('INSERT INTO #serverProperties SELECT
    ''MaintenancePlansEnabled'',
    CONVERT(varchar, COALESCE(count(*),0))
FROM
    msdb..sysmaintplan_plans p
    INNER JOIN msdb..sysmaintplan_subplans sp ON p.id = sp.plan_id
    INNER JOIN msdb..sysjobs j ON sp.job_id = j.job_id
WHERE
    j.[enabled] = 1');
END;
ELSE
BEGIN
exec('INSERT INTO #serverProperties VALUES (''MaintenancePlansEnabled'', CONVERT(varchar,0))');
END;

SELECT 
    @PKEY as PKEY,
    a.*,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
FROM #serverProperties a;

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;
IF OBJECT_ID('tempdb..#myPerms') IS NOT NULL  
   DROP TABLE #myPerms;