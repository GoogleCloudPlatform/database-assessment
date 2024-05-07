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

CREATE TABLE #serverProperties
(
    property_name nvarchar(256),
    property_value nvarchar(1024)
);

/* need to record table permissions in order to determine if we can run certain serverprops queryies
    as some tables are not available in managed instances
*/
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
    SELECT 'FilestreamConfiguredLevel', CONVERT(nvarchar, SERVERPROPERTY('FilestreamConfiguredLevel'))
UNION ALL
    SELECT 'FilestreamEffectiveLevel', CONVERT(nvarchar, SERVERPROPERTY('FilestreamEffectiveLevel'))
UNION ALL
    SELECT 'FullVersion', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), ' '), CHAR(10), ' '),1,1024)
UNION ALL
    SELECT 'LogicalCpuCount', CONVERT(varchar, cpu_count)
    from sys.dm_os_sys_info
UNION ALL
    SELECT 'PhysicalCpuCount', CONVERT(varchar, (cpu_count/hyperthread_ratio))
    from sys.dm_os_sys_info
UNION ALL
    SELECT 'SqlServerStartTime', CONVERT(varchar, (sqlserver_start_time))
    from sys.dm_os_sys_info
UNION ALL
    SELECT 'IsTDS80Used',
        CASE WHEN conn_type.tds8_count > 0 THEN '1' ELSE '0' END
    FROM (
        SELECT COUNT(*) as tds8_count
        from sys.dm_exec_connections
        WHERE sys.fn_varbintohexstr(protocol_version) like '0x8%'
    ) conn_type
UNION ALL
    SELECT 'IsResourceGovernorEnabled',
        CASE WHEN gov_enabled.enabled_count > 0 THEN '1' ELSE '0' END
    FROM (
        SELECT COUNT(*) as enabled_count
        from sys.resource_governor_configuration
        WHERE is_enabled = 1
    ) gov_enabled
UNION ALL
SELECT
    'IpV4Address', registry_data.ip_address
FROM (
    SELECT
        CONVERT(varchar(max), value_data) ip_address
    FROM
        sys.dm_server_registry
    WHERE
        value_name IN ('IpAddress')) registry_data
WHERE
    registry_data.ip_address LIKE '%.%.%.%'
    AND registry_data.ip_address NOT LIKE '127.%.%.%'
UNION ALL
SELECT
    TOP 1 'IpV6Address', registry_data.ip_address
FROM (
    SELECT
        CONVERT(varchar(max), value_data) ip_address
    FROM
        sys.dm_server_registry
    WHERE
        value_name IN ('IpAddress')) registry_data
WHERE
    registry_data.ip_address NOT LIKE '%.%.%.%'
    AND registry_data.ip_address NOT LIKE '127.%.%.%'
    AND registry_data.ip_address NOT LIKE '::1%'
;
WITH
    BUFFER_POOL_SIZE
    AS
    (
        SELECT database_id AS DatabaseID
		, DB_NAME(database_id) AS DatabaseName
		, COUNT(file_id) * 8 / 1024.0 AS BufferSizeInMB
        FROM sys.dm_os_buffer_descriptors
        GROUP BY DB_NAME(database_id)
		,database_id
    )
INSERT INTO #serverProperties
SELECT 'total_buffer_size_in_mb'
	, SUM(BufferSizeInMB)
FROM BUFFER_POOL_SIZE;

/* Certain clouds do not allow access to certain tables so we need to catch the table does not exist error and default the setting */
IF @CLOUDTYPE = 'AZURE'
BEGIN
    exec('INSERT INTO #serverProperties SELECT ''InstanceName'', CONVERT(nvarchar, COALESCE(SERVERPROPERTY(''InstanceName''),@@SERVERNAME))')
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''BackupsToAzureBlobStorage'', CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END from msdb.dbo.backupmediafamily where physical_device_name like ''%blob.core.windows.net%''')
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #serverProperties SELECT ''BackupsToAzureBlobStorage'', ''0''')
    END CATCH
    BEGIN TRY
        exec('INSERT INTO #serverProperties SELECT ''BackupsToObjectStorage'', CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END from msdb.dbo.backupmediafamily where (physical_device_name like ''%s3://%'') or (physical_device_name like ''%blob.core.windows.net%''')
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #serverProperties SELECT ''BackupsToObjectStorage'', ''0''')
    END CATCH
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
        exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', CONVERT(nvarchar, count(*)) from sys.availability_groups where dtc_support is not null /* SQL Server 2016 (13.x) and above */');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', ''0'' /* SQL Server 2016 (13.x) and above */');
    END CATCH

    exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', ''Azure VM''');
    exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', ''Linux''');
    exec('INSERT INTO #serverProperties SELECT ''HostRelease'', ''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', ''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'', ''UNKNOWN''');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryUsedInMB'', CONVERT(nvarchar, committed_kb/1024) FROM sys.dm_os_sys_info');
    exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryTargetInMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info');
    /* Derive total OS memory by choosing the max Target Node Memory for Azure SQL Database because regualr dm_os views are not available */
    exec('INSERT INTO #serverProperties SELECT ''TotalOSMemoryMB'', max(cntr_value)/1024 from sys.dm_os_performance_counters where UPPER(object_name) like ''%MEMORY NODE%'' and counter_name = ''Target Node Memory (KB)''')
    exec('INSERT INTO #serverProperties SELECT ''TotalSQLServerCommittedMemoryMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info')
    exec('INSERT INTO #serverProperties SELECT ''AvailableOSMemoryMB'', CONVERT(varchar, 0)')
    exec('INSERT INTO #serverProperties SELECT ''TotalMemoryInUseIncludingProcessesInMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info')
    exec('INSERT INTO #serverProperties SELECT ''TotalLockedPageAllocInMB'', CONVERT(varchar, 0)')
    exec('INSERT INTO #serverProperties SELECT ''TotalUserVirtualMemoryInMB'', CONVERT(varchar, 0)')
    exec('INSERT INTO #serverProperties SELECT ''MaxConfiguredSQLServerMemoryMB'', CASE WHEN value = maximum THEN ''0'' ELSE CONVERT(varchar, (value)) END from sys.configurations where name = ''max server memory (MB)''')
END
IF @CLOUDTYPE = 'NONE'
BEGIN
    exec('INSERT INTO #serverProperties SELECT ''InstanceName'', CONVERT(nvarchar, COALESCE(SERVERPROPERTY(''InstanceName''),@@ServiceName))')
    exec('INSERT INTO #serverProperties SELECT ''BackupsToAzureBlobStorage'', CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END from msdb.dbo.backupmediafamily where physical_device_name like ''%blob.core.windows.net%''')
    exec('INSERT INTO #serverProperties SELECT ''BackupsToObjectStorage'', CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END from msdb.dbo.backupmediafamily where (physical_device_name like ''%s3://%'') or (physical_device_name like ''%blob.core.windows.net%'')')
    exec('INSERT INTO #serverProperties SELECT ''IsRpcOutEnabled'', CONVERT(nvarchar, is_rpc_out_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    exec('INSERT INTO #serverProperties SELECT ''IsRemoteProcTransactionPromotionEnabled'', CONVERT(nvarchar, is_remote_proc_transaction_promotion_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    exec('INSERT INTO #serverProperties SELECT ''IsRemoteLoginEnabled'', CONVERT(nvarchar, is_remote_login_enabled) FROM sys.servers WHERE name = @@SERVERNAME')
    /* Query Memory usage at OS level */
    exec('INSERT INTO #serverProperties SELECT ''TotalOSMemoryMB'', CONVERT(varchar, (total_physical_memory_kb/1024)) FROM sys.dm_os_sys_memory')
    exec('INSERT INTO #serverProperties SELECT ''AvailableOSMemoryMB'', CONVERT(varchar, (available_physical_memory_kb/1024)) FROM sys.dm_os_sys_memory')
    exec('INSERT INTO #serverProperties SELECT ''TotalMemoryInUseIncludingProcessesInMB'', CONVERT(varchar, (physical_memory_in_use_kb/1024)) FROM sys.dm_os_process_memory')
    exec('INSERT INTO #serverProperties SELECT ''TotalLockedPageAllocInMB'', CONVERT(varchar, (locked_page_allocations_kb/1024)) FROM sys.dm_os_process_memory')
    exec('INSERT INTO #serverProperties SELECT ''TotalUserVirtualMemoryInMB'', CONVERT(varchar, (total_virtual_address_space_kb/1024)) FROM sys.dm_os_process_memory')
    exec('INSERT INTO #serverProperties SELECT ''MaxConfiguredSQLServerMemoryMB'', CASE WHEN value = maximum THEN ''0'' ELSE CONVERT(varchar, (value)) END from sys.configurations where name = ''max server memory (MB)''')
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
    BEGIN
        /* Versions before SQL Server 2012 (11.x)   */
        /* Must Query a different column for committed memory in versions below 11.x */
        exec('INSERT INTO #serverProperties SELECT ''TotalSQLServerCommittedMemoryMB'', CONVERT(nvarchar, bpool_committed/1024) FROM sys.dm_os_sys_info')
        exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', ''Windows''');
        exec('INSERT INTO #serverProperties SELECT ''HostRelease'', REPLACE(REPLACE(SUBSTRING(@@VERSION,4 + charindex ('' ON '',@@VERSION),LEN(@@VERSION)), CHAR(13), ''''), CHAR(10), '''')');
        exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', COALESCE(SUBSTRING(CONVERT(nvarchar,SERVERPROPERTY(''ProductLevel'')),1,1024), ''UNKNOWN'') ');
        exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',''UNKNOWN''');
        exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), '' ''), CHAR(10), '' ''),1,1024)');
        exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryUsedInMB'', CONVERT(nvarchar, 0) /* Parameter defaulted because its not avaliable in this version */');
        exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryTargetInMB'', CONVERT(nvarchar, 0) /* Parameter defaulted because its not avaliable in this version */');
    END;
    IF @PRODUCT_VERSION >= 13
    BEGIN
        exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', CONVERT(nvarchar, count(*)) from sys.availability_groups where dtc_support is not null /* SQL Server 2016 (13.x) and above */');
    END;
    ELSE
    BEGIN
        exec('INSERT INTO #serverProperties SELECT ''IsDTCInUse'', ''0'' /* SQL Server 2016 (13.x) and above */');
    END;
    IF @PRODUCT_VERSION >= 11
    BEGIN
        exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryUsedInMB'', CONVERT(nvarchar, committed_kb/1024) FROM sys.dm_os_sys_info /* SQL Server 2012 (11.x) above */');
        exec('INSERT INTO #serverProperties SELECT ''SQLServerMemoryTargetInMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info /* SQL Server 2012 (11.x) above */');
        /* Must Query a different column for committed memory in versions above 10.x */
        exec('INSERT INTO #serverProperties SELECT ''TotalSQLServerCommittedMemoryMB'', CONVERT(nvarchar, committed_target_kb/1024) FROM sys.dm_os_sys_info')
    END;
END;

SELECT
    QUOTENAME(@PKEY,'"')  as PKEY,
    QUOTENAME(a.property_name,'"') as property_name ,
    QUOTENAME(a.property_value,'"') as property_value,
    QUOTENAME(@DMA_SOURCE_ID,'"') as dma_source_id,
    QUOTENAME(@DMA_MANUAL_ID,'"') as dma_manual_id
FROM #serverProperties a;

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL
   DROP TABLE #serverProperties;
IF OBJECT_ID('tempdb..#myPerms') IS NOT NULL
   DROP TABLE #myPerms;
