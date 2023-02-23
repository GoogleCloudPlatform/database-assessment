SET NOCOUNT ON

IF OBJECT_ID('tempdb..#FeaturesEnabled') IS NOT NULL  
   DROP TABLE #FeaturesEnabled;  

CREATE TABLE #FeaturesEnabled
(
Features NVARCHAR(40),
Is_EnabledOrUsed NVARCHAR(4),
Count INT
)
--Log shipping
use master;
DECLARE @lsdbs TABLE(a char(100),b char(100),c char(100),d char(100), e char(100), f char(100), g char(100), h char(100), i char(100), j char(100), k char(100), l char(100), m char(100), n char(100), o char(100));
DECLARE @IS_LogShipping_Enabled as NVARCHAR(4), @log_shipping_count INT
insert INTO @lsdbs 
EXEC sp_help_log_shipping_monitor; 
select @log_shipping_count = count(*) from @lsdbs;
IF @log_shipping_count > 0 SET @IS_LogShipping_Enabled = 'Yes'  ELSE  SET @IS_LogShipping_Enabled = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Log Shipping', @IS_LogShipping_Enabled, @log_shipping_count );


--DB Mail
DECLARE @IS_DBMail_Enabled_value as INT, @IS_DBMail_Enabled as NVARCHAR(4)
SELECT @IS_DBMail_Enabled_value = CAST(value_in_use as INT)  FROM  sys.configurations WHERE name = 'Database Mail XPs';
IF @IS_DBMail_Enabled_value = 1 SET @IS_DBMail_Enabled = 'Yes'  ELSE  SET @IS_DBMail_Enabled = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Database Mail', @IS_DBMail_Enabled, 0 );

--external scripts enabled
DECLARE @ExtScriptsEnabled as INT, @IS_ExtScriptsEnabled as NVARCHAR(4);
Declare @extscript Table (a char(50), b int, c int, d int, e int )
insert  into @extscript exec sp_configure; 
select @ExtScriptsEnabled = e  
from @extscript where a='external scripts enabled';
IF @ExtScriptsEnabled > 0 SET @IS_ExtScriptsEnabled = 'Yes'  ELSE  SET @IS_ExtScriptsEnabled = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'External Scripts Enabled', @IS_ExtScriptsEnabled, @ExtScriptsEnabled );

--Resource Governor
DECLARE @ResourceGovernorEnabled as INT, @IS_ResourceGovernorEnabled as NVARCHAR(4);
select @ResourceGovernorEnabled = count(*)  FROM sys.resource_governor_workload_groups where group_id > 2;
IF @ResourceGovernorEnabled > 0 SET @IS_ResourceGovernorEnabled = 'Yes'  ELSE  SET @IS_ResourceGovernorEnabled = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Resource Governor Used', @IS_ResourceGovernorEnabled, @ResourceGovernorEnabled );

--Server level triggers
DECLARE @ServTriggersUsed as INT, @IS_ServTriggersUsed as NVARCHAR(4);
select @ServTriggersUsed = count(*) from sys.server_triggers;
IF @ServTriggersUsed > 0 SET @IS_ServTriggersUsed = 'Yes'  ELSE  SET @IS_ServTriggersUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Server level triggers Used', @IS_ServTriggersUsed, @ServTriggersUsed );

--Service Broker tasks
DECLARE @ServBrokerTasksUsed as INT, @IS_ServBrokerTasksUsed as NVARCHAR(4);
select @ServBrokerTasksUsed = count(*)  from sys.dm_broker_activated_tasks;
IF @ServBrokerTasksUsed > 0 SET @IS_ServBrokerTasksUsed = 'Yes'  ELSE  SET @IS_ServBrokerTasksUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Service Broker Tasks Used', @IS_ServBrokerTasksUsed, @ServBrokerTasksUsed );

--Endpoints
DECLARE @EndpointsUsed as INT, @IS_EndpointsUsed as NVARCHAR(4);
SELECT @EndpointsUsed = count(*)  FROM sys.endpoints where state = 0 and endpoint_id > 5;
IF @EndpointsUsed > 0 SET @IS_EndpointsUsed = 'Yes'  ELSE  SET @IS_EndpointsUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Endpoints Used', @IS_EndpointsUsed, @EndpointsUsed );

--External Assemblies
DECLARE @ExternalAssembliesUsed as INT, @IS_ExternalAssembliesUsed as NVARCHAR(4);
select @ExternalAssembliesUsed = COUNT(*) from sys.server_permissions where permission_name = 'External access assembly' and state='G';
IF @ExternalAssembliesUsed > 0 SET @IS_ExternalAssembliesUsed = 'Yes'  ELSE  SET @IS_ExternalAssembliesUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'External Assemblies Used', @IS_ExternalAssembliesUsed, @ExternalAssembliesUsed );

--CLR Enabled
DECLARE @CLREnabledUsed as INT, @IS_@CLREnabledUsed as NVARCHAR(4);
select @CLREnabledUsed = CAST(value_in_use AS INT) FROM  sys.configurations where name = 'clr enabled'
IF @CLREnabledUsed > 0 SET @IS_@CLREnabledUsed = 'Yes'  ELSE  SET @IS_@CLREnabledUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'CLR Enabled', @IS_@CLREnabledUsed, @CLREnabledUsed );

--Linked Servers
DECLARE @LinkedSrvUsed as INT, @IS_LinkedSrvUsed as NVARCHAR(4);
select @LinkedSrvUsed = count(*) from sys.servers where is_linked = 1
IF @LinkedSrvUsed > 0 SET @IS_LinkedSrvUsed = 'Yes'  ELSE  SET @IS_LinkedSrvUsed = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Linked Servers Used', @IS_LinkedSrvUsed, @LinkedSrvUsed );

--Policy based management
USE msdb;
DECLARE @PoliciesEnabled_value as INT, @IS_PoliciesEnabled as NVARCHAR(4)
SELECT @PoliciesEnabled_value = count(*) FROM syspolicy_policies where is_enabled =1;
IF @PoliciesEnabled_value > 0 SET @IS_PoliciesEnabled = 'Yes'  ELSE  SET @IS_PoliciesEnabled = 'No' ;
INSERT INTO #FeaturesEnabled VALUES (
'Policy Based Management', @IS_PoliciesEnabled, @PoliciesEnabled_value );

SELECT 
CAST(@@SERVERNAME + '_' + 'master' + '_' + @@ServiceName + '_' + FORMAT(GETDATE() , 'MMddyyHHmmss') AS VARCHAR(100)) AS PKEY,
* FROM #FeaturesEnabled;