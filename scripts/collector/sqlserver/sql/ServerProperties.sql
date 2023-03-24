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
SELECT @PRODUCT_VERSION = PARSENAME(CAST(SERVERPROPERTY('productversion') AS varchar(20)), 4);
SELECT @PKEY = N'$(pkey)';

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;

CREATE TABLE #serverProperties(
    property_name nvarchar(255)
    ,property_value nvarchar(255)
);
    
INSERT INTO #serverProperties
SELECT 'BuildClrVersion' AS Property, SERVERPROPERTY('BuildClrVersion') AS Value
UNION ALL
SELECT 'Collation', SERVERPROPERTY('Collation')
UNION ALL
SELECT 'CollationID', SERVERPROPERTY('CollationID')
UNION ALL
SELECT 'ComparisonStyle', SERVERPROPERTY('ComparisonStyle')
UNION ALL
SELECT 'Edition', SERVERPROPERTY('Edition')
UNION ALL
SELECT 'EditionID', SERVERPROPERTY('EditionID')
UNION ALL
SELECT 'EngineEdition', SERVERPROPERTY('EngineEdition')
UNION ALL
SELECT 'HadrManagerStatus', SERVERPROPERTY('HadrManagerStatus')
UNION ALL
SELECT 'InstanceName', SERVERPROPERTY('InstanceName')
UNION ALL
SELECT 'IsAdvancedAnalyticsInstalled', SERVERPROPERTY('IsAdvancedAnalyticsInstalled')
UNION ALL
SELECT 'IsClustered', SERVERPROPERTY('IsClustered')
UNION ALL
SELECT 'IsFullTextInstalled', SERVERPROPERTY('IsFullTextInstalled')
UNION ALL
SELECT 'IsHadrEnabled', SERVERPROPERTY('IsHadrEnabled')
UNION ALL
SELECT 'IsIntegratedSecurityOnly', SERVERPROPERTY('IsIntegratedSecurityOnly')
UNION ALL
SELECT 'IsLocalDB', SERVERPROPERTY('IsLocalDB')
UNION ALL
SELECT 'IsPolyBaseInstalled', SERVERPROPERTY('IsPolyBaseInstalled')
UNION ALL
SELECT 'IsSingleUser', SERVERPROPERTY('IsSingleUser')
UNION ALL
SELECT 'IsXTPSupported', SERVERPROPERTY('IsXTPSupported')
UNION ALL
SELECT 'LCID', SERVERPROPERTY('LCID')
UNION ALL
SELECT 'LicenseType', SERVERPROPERTY('LicenseType')
UNION ALL
SELECT 'MachineName', SERVERPROPERTY('MachineName')
UNION ALL
SELECT 'NumLicenses', SERVERPROPERTY('NumLicenses')
UNION ALL
SELECT 'ProcessID', SERVERPROPERTY('ProcessID')
UNION ALL
SELECT 'ProductBuild', SERVERPROPERTY('ProductBuild')
UNION ALL
SELECT 'ProductBuildType', SERVERPROPERTY('ProductBuildType')
UNION ALL
SELECT 'ProductLevel', SERVERPROPERTY('ProductLevel')
UNION ALL
SELECT 'ProductMajorVersion', SERVERPROPERTY('ProductMajorVersion')
UNION ALL
SELECT 'ProductMinorVersion', SERVERPROPERTY('ProductMinorVersion')
UNION ALL
SELECT 'ProductUpdateLevel', SERVERPROPERTY('ProductUpdateLevel')
UNION ALL
SELECT 'ProductUpdateReference', SERVERPROPERTY('ProductUpdateReference')
UNION ALL
SELECT 'ProductVersion', SERVERPROPERTY('ProductVersion')
UNION ALL
SELECT 'ResourceLastUpdateDateTime', SERVERPROPERTY('ResourceLastUpdateDateTime')
UNION ALL
SELECT 'ResourceVersion', SERVERPROPERTY('ResourceVersion')
UNION ALL
SELECT 'ServerName', SERVERPROPERTY('ServerName')
UNION ALL
SELECT 'SqlCharSet', SERVERPROPERTY('SqlCharSet')
UNION ALL
SELECT 'SqlCharSetName', SERVERPROPERTY('SqlCharSetName')
UNION ALL
SELECT 'SqlSortOrder', SERVERPROPERTY('SqlSortOrder')
UNION ALL
SELECT 'SqlSortOrderName', SERVERPROPERTY('SqlSortOrderName')
UNION ALL
SELECT 'FilestreamShareName', SERVERPROPERTY('FilestreamShareName')
UNION ALL
SELECT 'FilestreamConfiguredLevel', SERVERPROPERTY('FilestreamConfiguredLevel')
UNION ALL
SELECT 'FilestreamEffectiveLevel', SERVERPROPERTY('FilestreamEffectiveLevel')
UNION ALL
SELECT 'IsRpcOutEnabled', is_rpc_out_enabled FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT 'IsRemoteProcTransactionPromotionEnabled', is_remote_proc_transaction_promotion_enabled FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT 'IsBufferPoolExtensionEnabled', state FROM sys.dm_os_buffer_pool_extension_configuration
UNION ALL
SELECT 'IsRemoteLoginEnabled', is_remote_login_enabled FROM sys.servers WHERE name = @@SERVERNAME;
IF @PRODUCT_VERSION >= 15
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''IsHybridBufferPoolEnabled'', CONVERT(varchar,is_enabled) from sys.server_memory_optimized_hybrid_buffer_pool_configuration /* SQL Server 2019 (15.x) and later versions */');
END;
IF @PRODUCT_VERSION >= 14
BEGIN
 exec('INSERT INTO #serverProperties SELECT ''HostPlatform'', host_platform FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostDistribution'', host_distribution FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostRelease'', host_release FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostServicePackLevel'', host_service_pack_level FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
 exec('INSERT INTO #serverProperties SELECT ''HostOsLanguageVersion'', os_language_version FROM sys.dm_os_host_info /* SQL Server 2017 (14.x) and later */');
END;

SELECT @PKEY as PKEY, a.* FROM #serverProperties a;

IF OBJECT_ID('tempdb..#serverProperties') IS NOT NULL  
   DROP TABLE #serverProperties;