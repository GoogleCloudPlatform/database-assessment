--from https://database.guide/quick-script-that-returns-all-properties-from-serverproperty-in-sql-server-2017-2019/
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
SELECT 'FilestreamEffectiveLevel', SERVERPROPERTY('FilestreamEffectiveLevel');