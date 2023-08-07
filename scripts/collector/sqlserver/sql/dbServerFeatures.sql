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

SET NOCOUNT ON;
SET LANGUAGE us_english;

DECLARE @PKEY AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER

SELECT @PKEY = N'$(pkey)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @CLOUDTYPE = 'NONE'
IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF OBJECT_ID('tempdb..#FeaturesEnabled') IS NOT NULL  
   DROP TABLE #FeaturesEnabled;  

CREATE TABLE #FeaturesEnabled
(
Features NVARCHAR(40),
Is_EnabledOrUsed NVARCHAR(4),
Count INT
)

--DB Mail
BEGIN
    DECLARE @IS_DBMail_Enabled_value as INT, @IS_DBMail_Enabled as NVARCHAR(4)
    SELECT @IS_DBMail_Enabled_value = CAST(value_in_use as INT)  FROM  sys.configurations WHERE name = 'Database Mail XPs';
    IF @IS_DBMail_Enabled_value = 1 SET @IS_DBMail_Enabled = 'Yes'  ELSE  SET @IS_DBMail_Enabled = 'No' ;

    INSERT INTO #FeaturesEnabled VALUES (
    'Database Mail', 
    @IS_DBMail_Enabled, 
    CASE WHEN @IS_DBMail_Enabled_value > 0 THEN @IS_DBMail_Enabled_value 
    ELSE 0
    END);
END

--external scripts enabled
BEGIN
    DECLARE @ExtScriptsEnabled as INT, @IS_ExtScriptsEnabled as NVARCHAR(4);
    SELECT @ExtScriptsEnabled = CAST(value_in_use as INT)  FROM  sys.configurations WHERE name = 'external scripts enabled';
    IF @ExtScriptsEnabled > 0 SET @IS_ExtScriptsEnabled = 'Yes'  ELSE  SET @IS_ExtScriptsEnabled = 'No' ;
    INSERT INTO #FeaturesEnabled VALUES (
    'External Scripts Enabled', @IS_ExtScriptsEnabled, ISNULL(@ExtScriptsEnabled,0));
END

--Resource Governor
DECLARE @ResourceGovernorEnabled as INT, @IS_ResourceGovernorEnabled as NVARCHAR(4);
select @ResourceGovernorEnabled = count(*)  FROM sys.resource_governor_workload_groups where group_id > 2;
IF @ResourceGovernorEnabled > 0 SET @IS_ResourceGovernorEnabled = 'Yes'  ELSE  SET @IS_ResourceGovernorEnabled = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Resource Governor Used', @IS_ResourceGovernorEnabled, ISNULL(@ResourceGovernorEnabled,0) );

--Server level triggers
/* Covered in the serverproperties query 
DECLARE @ServTriggersUsed as INT, @IS_ServTriggersUsed as NVARCHAR(4);
select @ServTriggersUsed = count(*) from sys.server_triggers;
IF @ServTriggersUsed > 0 SET @IS_ServTriggersUsed = 'Yes'  ELSE  SET @IS_ServTriggersUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Server level triggers Used', @IS_ServTriggersUsed, ISNULL(@ServTriggersUsed,0) ); */

--Service Broker tasks
DECLARE @ServBrokerTasksUsed as INT, @IS_ServBrokerTasksUsed as NVARCHAR(4);
select @ServBrokerTasksUsed = count(*)  from sys.dm_broker_activated_tasks;
IF @ServBrokerTasksUsed > 0 SET @IS_ServBrokerTasksUsed = 'Yes'  ELSE  SET @IS_ServBrokerTasksUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Service Broker Tasks Used', @IS_ServBrokerTasksUsed, ISNULL(@ServBrokerTasksUsed,0) );

--Endpoints
/* Covered in the serverproperties query 
DECLARE @EndpointsUsed as INT, @IS_EndpointsUsed as NVARCHAR(4);
SELECT @EndpointsUsed = count(*)  FROM sys.tcp_endpoints where state = 0 and endpoint_id > 5;
IF @EndpointsUsed > 0 SET @IS_EndpointsUsed = 'Yes'  ELSE  SET @IS_EndpointsUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Endpoints Used', @IS_EndpointsUsed, ISNULL(@EndpointsUsed,0) ); */

--External Assemblies
IF @CLOUDTYPE = 'AZURE'
BEGIN
    INSERT INTO #FeaturesEnabled VALUES (
    'External Assemblies Used', 'No', 0);
END
ELSE
BEGIN
    DECLARE @ExternalAssembliesUsed as INT, @IS_ExternalAssembliesUsed as NVARCHAR(4);
    select @ExternalAssembliesUsed = COUNT(*) from sys.server_permissions where permission_name = 'External access assembly' and state='G';
    IF @ExternalAssembliesUsed > 0 SET @IS_ExternalAssembliesUsed = 'Yes'  ELSE  SET @IS_ExternalAssembliesUsed = 'No' ;
    INSERT INTO #FeaturesEnabled VALUES (
    'External Assemblies Used', @IS_ExternalAssembliesUsed, ISNULL(@ExternalAssembliesUsed,0) );
END

--CLR Enabled
DECLARE @CLREnabledUsed as INT, @IS_@CLREnabledUsed as NVARCHAR(4);
select @CLREnabledUsed = CAST(value_in_use AS INT) FROM  sys.configurations where name = 'clr enabled'
IF @CLREnabledUsed > 0 SET @IS_@CLREnabledUsed = 'Yes'  ELSE  SET @IS_@CLREnabledUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'CLR Enabled', @IS_@CLREnabledUsed, ISNULL(@CLREnabledUsed,0) );

--Linked Servers
IF @CLOUDTYPE = 'AZURE'
BEGIN
    INSERT INTO #FeaturesEnabled VALUES (
    'Linked Servers Used', 'No', 0);
END
ELSE
BEGIN
    DECLARE @LinkedSrvUsed as INT, @IS_LinkedSrvUsed as NVARCHAR(4);
    select @LinkedSrvUsed = count(*) from sys.servers where is_linked = 1
    IF @LinkedSrvUsed > 0 SET @IS_LinkedSrvUsed = 'Yes'  ELSE  SET @IS_LinkedSrvUsed = 'No' ;
    INSERT INTO #FeaturesEnabled VALUES (
    'Linked Servers Used', @IS_LinkedSrvUsed, ISNULL(@LinkedSrvUsed,0) );
END

--Policy based management
DECLARE @PoliciesEnabled_value as INT, @IS_PoliciesEnabled as NVARCHAR(4)
BEGIN TRY
    exec('SELECT @PoliciesEnabled_value = count(*) FROM msdb.dbo.syspolicy_policies where is_enabled =1;
	IF @PoliciesEnabled_value > 0 SET @IS_PoliciesEnabled = ''Yes''  ELSE  SET @IS_PoliciesEnabled = ''No'' ;
	INSERT INTO #FeaturesEnabled VALUES (
		''Policy Based Management'', @IS_PoliciesEnabled, ISNULL(@PoliciesEnabled_value,0) );');
END TRY
BEGIN CATCH
	IF ERROR_NUMBER() = 40515 AND ERROR_SEVERITY() = 15 AND ERROR_STATE() = 1
    exec('INSERT INTO #FeaturesEnabled VALUES (''Policy Based Management'', ''No'', ''0'')')
END CATCH

SELECT @PKEY as PKEY, * FROM #FeaturesEnabled;