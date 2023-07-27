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
DECLARE @INSTANCENAME AS VARCHAR(256)
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @INSTANCENAME = SUBSTRING(REPLACE(CONVERT(NVARCHAR(255), service_broker_guid),'-',''),0,15) FROM sys.databases where name = 'master'
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = 'master'
BEGIN TRY
	exec('
	SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR(15)) AS Version, 
	UPPER(CONVERT(varchar, HOST_NAME())) as machinename, 
	''' + @ASSESSMENT_DATABSE_NAME + ''' as databasename,
	@@ServiceName as instancename,
	replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') as current_ts,
	UPPER(CONVERT(varchar, HOST_NAME())) + ''_'' + ''' + @ASSESSMENT_DATABSE_NAME + ''' + ''_'' +  @@ServiceName + ''_'' + replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') as pkey');
END TRY
BEGIN CATCH
	exec('
	DECLARE @CLOUDTYPE AS VARCHAR(256)
	IF UPPER(@@VERSION) LIKE ''%AZURE%''
		SELECT @CLOUDTYPE = ''AZURE''
	SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR(15)) AS Version, 
	UPPER(CONVERT(varchar, HOST_NAME())) as machinename, 
	''' + @ASSESSMENT_DATABSE_NAME + ''' as databasename,
	@@SERVERNAME as instancename, 
	replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') as current_ts,
	CASE WHEN @CLOUDTYPE IS NOT NULL
	THEN
		''' + @INSTANCENAME + ''' + ''-'' + @CLOUDTYPE + ''_'' + ''' + @ASSESSMENT_DATABSE_NAME + ''' + ''_'' + @@SERVERNAME + ''_'' + replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''')
	ELSE
		''' + @INSTANCENAME + ''' + ''_'' + ''' + @ASSESSMENT_DATABSE_NAME + ''' + ''_'' + @@SERVERNAME + ''_'' + replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''')
	END as pkey');
END CATCH