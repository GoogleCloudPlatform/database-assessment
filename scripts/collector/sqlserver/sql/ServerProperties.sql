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
select @PKEY = N'$(pkey)';
SELECT @PKEY as PKEY,'BuildClrVersion' AS Property, SERVERPROPERTY('BuildClrVersion') AS Value
UNION ALL
SELECT @PKEY as PKEY,'Collation', SERVERPROPERTY('Collation')
UNION ALL
SELECT @PKEY as PKEY,'CollationID', SERVERPROPERTY('CollationID')
UNION ALL
SELECT @PKEY as PKEY,'ComparisonStyle', SERVERPROPERTY('ComparisonStyle')
UNION ALL
SELECT @PKEY as PKEY,'Edition', SERVERPROPERTY('Edition')
UNION ALL
SELECT @PKEY as PKEY,'EditionID', SERVERPROPERTY('EditionID')
UNION ALL
SELECT @PKEY as PKEY,'EngineEdition', SERVERPROPERTY('EngineEdition')
UNION ALL
SELECT @PKEY as PKEY,'HadrManagerStatus', SERVERPROPERTY('HadrManagerStatus')
UNION ALL
SELECT @PKEY as PKEY,'InstanceName', SERVERPROPERTY('InstanceName')
UNION ALL
SELECT @PKEY as PKEY,'IsAdvancedAnalyticsInstalled', SERVERPROPERTY('IsAdvancedAnalyticsInstalled')
UNION ALL
SELECT @PKEY as PKEY,'IsClustered', SERVERPROPERTY('IsClustered')
UNION ALL
SELECT @PKEY as PKEY,'IsFullTextInstalled', SERVERPROPERTY('IsFullTextInstalled')
UNION ALL
SELECT @PKEY as PKEY,'IsHadrEnabled', SERVERPROPERTY('IsHadrEnabled')
UNION ALL
SELECT @PKEY as PKEY,'IsIntegratedSecurityOnly', SERVERPROPERTY('IsIntegratedSecurityOnly')
UNION ALL
SELECT @PKEY as PKEY,'IsLocalDB', SERVERPROPERTY('IsLocalDB')
UNION ALL
SELECT @PKEY as PKEY,'IsPolyBaseInstalled', SERVERPROPERTY('IsPolyBaseInstalled')
UNION ALL
SELECT @PKEY as PKEY,'IsSingleUser', SERVERPROPERTY('IsSingleUser')
UNION ALL
SELECT @PKEY as PKEY,'IsXTPSupported', SERVERPROPERTY('IsXTPSupported')
UNION ALL
SELECT @PKEY as PKEY,'LCID', SERVERPROPERTY('LCID')
UNION ALL
SELECT @PKEY as PKEY,'LicenseType', SERVERPROPERTY('LicenseType')
UNION ALL
SELECT @PKEY as PKEY,'MachineName', SERVERPROPERTY('MachineName')
UNION ALL
SELECT @PKEY as PKEY,'NumLicenses', SERVERPROPERTY('NumLicenses')
UNION ALL
SELECT @PKEY as PKEY,'ProcessID', SERVERPROPERTY('ProcessID')
UNION ALL
SELECT @PKEY as PKEY,'ProductBuild', SERVERPROPERTY('ProductBuild')
UNION ALL
SELECT @PKEY as PKEY,'ProductBuildType', SERVERPROPERTY('ProductBuildType')
UNION ALL
SELECT @PKEY as PKEY,'ProductLevel', SERVERPROPERTY('ProductLevel')
UNION ALL
SELECT @PKEY as PKEY,'ProductMajorVersion', SERVERPROPERTY('ProductMajorVersion')
UNION ALL
SELECT @PKEY as PKEY,'ProductMinorVersion', SERVERPROPERTY('ProductMinorVersion')
UNION ALL
SELECT @PKEY as PKEY,'ProductUpdateLevel', SERVERPROPERTY('ProductUpdateLevel')
UNION ALL
SELECT @PKEY as PKEY,'ProductUpdateReference', SERVERPROPERTY('ProductUpdateReference')
UNION ALL
SELECT @PKEY as PKEY,'ProductVersion', SERVERPROPERTY('ProductVersion')
UNION ALL
SELECT @PKEY as PKEY,'ResourceLastUpdateDateTime', SERVERPROPERTY('ResourceLastUpdateDateTime')
UNION ALL
SELECT @PKEY as PKEY,'ResourceVersion', SERVERPROPERTY('ResourceVersion')
UNION ALL
SELECT @PKEY as PKEY,'ServerName', SERVERPROPERTY('ServerName')
UNION ALL
SELECT @PKEY as PKEY,'SqlCharSet', SERVERPROPERTY('SqlCharSet')
UNION ALL
SELECT @PKEY as PKEY,'SqlCharSetName', SERVERPROPERTY('SqlCharSetName')
UNION ALL
SELECT @PKEY as PKEY,'SqlSortOrder', SERVERPROPERTY('SqlSortOrder')
UNION ALL
SELECT @PKEY as PKEY,'SqlSortOrderName', SERVERPROPERTY('SqlSortOrderName')
UNION ALL
SELECT @PKEY as PKEY,'FilestreamShareName', SERVERPROPERTY('FilestreamShareName')
UNION ALL
SELECT @PKEY as PKEY,'FilestreamConfiguredLevel', SERVERPROPERTY('FilestreamConfiguredLevel')
UNION ALL
SELECT @PKEY as PKEY,'FilestreamEffectiveLevel', SERVERPROPERTY('FilestreamEffectiveLevel')
UNION ALL
SELECT @PKEY as PKEY,'HostPlatform', host_platform FROM sys.dm_os_host_info
UNION ALL
SELECT @PKEY as PKEY,'HostDistribution', host_distribution FROM sys.dm_os_host_info
UNION ALL
SELECT @PKEY as PKEY,'HostRelease', host_release FROM sys.dm_os_host_info
UNION ALL
SELECT @PKEY as PKEY,'HostServicePackLevel', host_service_pack_level FROM sys.dm_os_host_info
UNION ALL
SELECT @PKEY as PKEY,'HostOsLanguageVersion', os_language_version FROM sys.dm_os_host_info
UNION ALL
SELECT @PKEY as PKEY,'IsRemoteLoginEnabled', is_remote_login_enabled FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT @PKEY as PKEY,'IsRpcOutEnabled', is_rpc_out_enabled FROM sys.servers WHERE name = @@SERVERNAME
UNION ALL
SELECT @PKEY as PKEY,'IsRemoteProcTransactionPromotionEnabled', is_remote_proc_transaction_promotion_enabled FROM sys.servers WHERE name = @@SERVERNAME
;