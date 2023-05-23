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
DECLARE @PRODUCT_VERSION AS INTEGER
SELECT @PRODUCT_VERSION = CONVERT(integer, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @PKEY = N'$(pkey)';

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;

CREATE TABLE #serverProperties(
    property_name nvarchar(256)
    ,property_value nvarchar(1024)
);
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
SELECT 'HadrManagerStatus', CONVERT(nvarchar, SERVERPROPERTY('HadrManagerStatus'))
UNION ALL
SELECT 'InstanceName', CONVERT(nvarchar, SERVERPROPERTY('InstanceName'))
UNION ALL
SELECT 'IsAdvancedAnalyticsInstalled', CONVERT(nvarchar, SERVERPROPERTY('IsAdvancedAnalyticsInstalled'))
UNION ALL
SELECT 'IsClustered', CONVERT(nvarchar, SERVERPROPERTY('IsClustered'))
UNION ALL
SELECT 'IsFullTextInstalled', CONVERT(nvarchar, SERVERPROPERTY('IsFullTextInstalled'))
UNION ALL
SELECT 'IsHadrEnabled', CONVERT(nvarchar, SERVERPROPERTY('IsHadrEnabled'))
UNION ALL
SELECT 'IsIntegratedSecurityOnly', CONVERT(nvarchar, SERVERPROPERTY('IsIntegratedSecurityOnly'))
UNION ALL
SELECT 'IsLocalDB', CONVERT(nvarchar, SERVERPROPERTY('IsLocalDB'))
UNION ALL
SELECT 'IsPolyBaseInstalled', CONVERT(nvarchar, SERVERPROPERTY('IsPolyBaseInstalled'))
UNION ALL
SELECT 'IsSingleUser', CONVERT(nvarchar, SERVERPROPERTY('IsSingleUser'))
UNION ALL
SELECT 'IsXTPSupported', CONVERT(nvarchar, SERVERPROPERTY('IsXTPSupported'))
UNION ALL
SELECT 'LCID', CONVERT(nvarchar, SERVERPROPERTY('LCID'))
UNION ALL
SELECT 'LicenseType', CONVERT(nvarchar, SERVERPROPERTY('LicenseType'))
UNION ALL
SELECT 'MachineName', CONVERT(nvarchar, SERVERPROPERTY('MachineName'))
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
SELECT 'FilestreamShareName', CONVERT(nvarchar, SERVERPROPERTY('FilestreamShareName'))
UNION ALL
SELECT 'FilestreamConfiguredLevel', CONVERT(nvarchar, SERVERPROPERTY('FilestreamConfiguredLevel'))
UNION ALL
SELECT 'FilestreamEffectiveLevel', CONVERT(nvarchar, SERVERPROPERTY('FilestreamEffectiveLevel'))
UNION ALL
SELECT 'IsRpcOutEnabled', CONVERT(nvarchar, is_rpc_out_enabled) FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT 'IsRemoteProcTransactionPromotionEnabled', CONVERT(nvarchar, is_remote_proc_transaction_promotion_enabled) FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT 'IsRemoteLoginEnabled', CONVERT(nvarchar, is_remote_login_enabled) FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT 'FullVersion', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), ' '), CHAR(10), ' '),1,1024)
UNION ALL
SELECT
    'MaintenancePlansEnabled',
    CONVERT(nvarchar, count(*))
FROM
    msdb..sysmaintplan_plans p
    INNER JOIN msdb..sysmaintplan_subplans sp ON p.id = sp.plan_id
    INNER JOIN msdb..sysjobs j ON sp.job_id = j.job_id
WHERE
    j.[enabled] = 1
UNION ALL
SELECT
    'IsDbMailEnabled', CONVERT(nvarchar, count(*))
FROM
    msdb.dbo.sysmail_profile p
    JOIN msdb.dbo.sysmail_profileaccount pa ON p.profile_id = pa.profile_id
    JOIN msdb.dbo.sysmail_account a ON pa.account_id = a.account_id
    JOIN msdb.dbo.sysmail_server s ON a.account_id = s.account_id
UNION ALL
SELECT 'IsTempDbMetadataMemoryOptimized', CONVERT(varchar, value_in_use) from sys.configurations where name = 'tempdb metadata memory-optimized'
UNION ALL
SELECT 'IsPolybaseEnabled', CONVERT(varchar, value_in_use) from sys.configurations where name = 'polybase enabled'
UNION ALL
SELECT 'IsExternalScriptsEnabled', CONVERT(varchar, value_in_use) from sys.configurations where name = 'external scripts enabled'
UNION ALL
SELECT 'IsCLREnabled', CONVERT(varchar, value_in_use) from sys.configurations where name = 'clr enabled'
UNION ALL
SELECT 'IsResourceGovenorEnabled', CONVERT(varchar, is_enabled) from sys.resource_governor_configuration
UNION ALL
SELECT 'IsTDEInUse', CONVERT(nvarchar, count(*)) from sys.databases where is_encrypted <> 0
UNION ALL
SELECT 'ServerLevelTriggers', CONVERT(varchar, count(*)) from sys.server_triggers
UNION ALL
SELECT 'CountServiceBrokerEndpoints', CONVERT(varchar, count(*)) from sys.service_broker_endpoints
UNION ALL
SELECT 'LogicalCpuCount', CONVERT(varchar, cpu_count) from sys.dm_os_sys_info
UNION ALL
SELECT 'PhysicalCpuCount', CONVERT(varchar, (cpu_count/hyperthread_ratio)) from sys.dm_os_sys_info
UNION ALL
SELECT 'SqlServerStartTime', CONVERT(varchar, (sqlserver_start_time)) from sys.dm_os_sys_info
UNION ALL
SELECT 'CountTSQLEndpoints', CONVERT(varchar, count(*)) from sys.tcp_endpoints where endpoint_id > 65535
UNION ALL
SELECT 'BULK_INSERT', CONVERT(varchar,count(p.permission_name)) FROM fn_my_permissions(NULL, 'SERVER') p WHERE permission_name like '%ADMINISTER BULK OPERATIONS%';
WITH check_sysadmin_role AS (
    SELECT
        name,
        type_desc,
        is_disabled
    FROM
        master.sys.server_principals
    WHERE
        IS_SRVROLEMEMBER ('sysadmin', name) = 1
        AND name NOT LIKE '%NT SERVICE%'
    UNION
    SELECT
        name,
        type_desc,
        is_disabled
    FROM
        master.sys.server_principals
    WHERE
        IS_SRVROLEMEMBER ('dbcreator', name) = 1
        AND name NOT LIKE '%NT SERVICE%'
)
INSERT INTO #serverProperties SELECT
    'sysadmin_role',
    CONVERT(varchar, count(*))
FROM
    check_sysadmin_role;
WITH log_shipping_count AS (
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
    'IsLogShippingEnabled', CONVERT(varchar,sum(log_shipping))
FROM
    log_shipping_count;
IF @PRODUCT_VERSION >= 15
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''IsHybridBufferPoolEnabled'', CONVERT(nvarchar,is_enabled) from sys.server_memory_optimized_hybrid_buffer_pool_configuration /* SQL Server 2019 (15.x) and later versions */');
END;
IF @PRODUCT_VERSION < 14
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', ''Windows'' FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and prior */');
 exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', SUBSTRING(REPLACE(REPLACE(@@version, CHAR(13), '' ''), CHAR(10), '' ''),1,1024) /* SQL Server 2016 (13.x) and prior */');
 exec('INSERT INTO #serverProperties SELECT ''HostRelease'', SUBSTRING(CONVERT(nvarchar,windows_release),1,1024) FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and prior */');
 exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', SUBSTRING(CONVERT(nvarchar,windows_service_pack_level),1,1024) FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and prior */');
 exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',SUBSTRING(CONVERT(nvarchar, os_language_version),1,1024) FROM sys.dm_os_windows_info /* SQL Server 2016 (13.x) and prior */');
END;
IF @PRODUCT_VERSION >= 14
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', SUBSTRING(CONVERT(nvarchar,host_platform),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', SUBSTRING(CONVERT(nvarchar,host_distribution),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostRelease'', SUBSTRING(CONVERT(nvarchar,host_release),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', SUBSTRING(CONVERT(nvarchar,host_service_pack_level),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',SUBSTRING(CONVERT(nvarchar, os_language_version),1,1024) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
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

SELECT @PKEY as PKEY, a.* FROM #serverProperties a;

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;