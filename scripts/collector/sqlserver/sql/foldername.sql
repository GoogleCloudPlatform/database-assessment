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

DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @MACHINENAME AS VARCHAR(256)

SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @CLOUDTYPE = 'NONE'
IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'
	SELECT @MACHINENAME = SUBSTRING(REPLACE(CONVERT(NVARCHAR(255), service_broker_guid),'-',''),0,15) FROM sys.databases where name = 'master'

SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = 'master'

BEGIN
	exec('
	SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR(15)) AS Version,
	COALESCE(CONVERT(nvarchar, @@SERVERNAME), ''' + @MACHINENAME + '''  + ''-'' + ''' + @CLOUDTYPE + ''') as machinename,
	''' + @ASSESSMENT_DATABSE_NAME + ''' as databasename,
	COALESCE(CONVERT(nvarchar, SERVERPROPERTY(''InstanceName'')), ''MSSQLSERVER'') as instancename,
	replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') as current_ts,
	CASE WHEN ''' + @CLOUDTYPE + ''' = ''AZURE''
	THEN 
	   UPPER(CONVERT(nvarchar, @@SERVERNAME)) + ''-'' + ''' + @CLOUDTYPE + ''' + ''_'' + ''' + @ASSESSMENT_DATABSE_NAME + ''' + ''_'' +  COALESCE(CONVERT(nvarchar, SERVERPROPERTY(''InstanceName'')), ''MSSQLSERVER'') + ''_'' + replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') 
	ELSE
	   UPPER(CONVERT(nvarchar, @@SERVERNAME)) + ''_'' + ''' + @ASSESSMENT_DATABSE_NAME + ''' + ''_'' +  COALESCE(CONVERT(nvarchar, SERVERPROPERTY(''InstanceName'')), ''MSSQLSERVER'') + ''_'' + replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') 
	END as pkey');
END