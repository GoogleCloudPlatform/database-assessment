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

This script access Automatic Repository Workload (AWR) views in the database dictionary.
Please ensure you have proper licensing. For more information consult Oracle Support Doc ID 1490798.1

*/

/* sys.dm_os_host_info - Applies to: SQL Server 2017 (14.x) and later */
SET NOCOUNT ON
DECLARE @PKEY AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS VARCHAR(30)
SELECT @PRODUCT_VERSION = PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4);
SELECT @PKEY = N'$(pkey)';

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;

CREATE TABLE #serverProperties(
    property_name nvarchar(255)
    ,property_value nvarchar(255)
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
SELECT 'ResourceLastUpdateDateTime', CONVERT(nvarchar, SERVERPROPERTY('ResourceLastUpdateDateTime'))
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
SELECT 'IsBufferPoolExtensionEnabled', CONVERT(nvarchar, state) FROM sys.dm_os_buffer_pool_extension_configuration
UNION ALL
SELECT 'IsRemoteLoginEnabled', CONVERT(nvarchar, is_remote_login_enabled) FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT 'IsFileStreamEmabled', CONVERT(nvarchar, count(*)) FROM sys.database_filestream_options where non_transacted_access <> 0
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
SELECT 'IsDTCInUse', CONVERT(nvarchar, count(*)) from sys.availability_groups where dtc_support is not null
UNION ALL
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
SELECT
    'IsLogShippingEnabled', CONVERT(varchar,sum(log_shipping))
FROM
    log_shipping_count
UNION ALL
SELECT 'ServerLevelTriggers', CONVERT(varchar, count(*)) from sys.server_triggers
UNION ALL
SELECT 'CountServiceBrokerEndpoints', CONVERT(varchar, count(*)) from sys.service_broker_endpoints
UNION ALL
SELECT 'CountTSQLEndpoints', CONVERT(varchar, count(*)) from sys.tcp_endpoints where endpoint_id > 65535;
IF @PRODUCT_VERSION >= 15
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''IsHybridBufferPoolEnabled'', CONVERT(nvarchar,is_enabled) from sys.server_memory_optimized_hybrid_buffer_pool_configuration /* SQL Server 2019 (15.x) and later versions */');
END;
IF @PRODUCT_VERSION >= 14
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', CONVERT(nvarchar,host_platform) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', CONVERT(nvarchar,host_distribution) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostRelease'', CONVERT(nvarchar,host_release) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', CONVERT(nvarchar,host_service_pack_level) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'',CONVERT(nvarchar, os_language_version) FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
END;
IF @PRODUCT_VERSION >= 13 AND @PRODUCT_VERSION <= 16
BEGIN
exec('INSERT INTO #serverProperties SELECT ''IsStretchDatabaseEnabled'', CONVERT(nvarchar, count(*)) FROM sys.remote_data_archive_databases /* SQL Server 2016 (13.x) and Up to 2022 */');
END;


SELECT @PKEY as PKEY, a.* FROM #serverProperties a;

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;