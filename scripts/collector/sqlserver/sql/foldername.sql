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
DECLARE @MACHINE_NAME AS VARCHAR(256)

SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = 'master'

IF CHARINDEX('\', @@SERVERNAME)-1 = -1
  SELECT @MACHINE_NAME = UPPER(@@SERVERNAME)
ELSE
  SELECT @MACHINE_NAME = UPPER(SUBSTRING(CONVERT(NVARCHAR(255), @@SERVERNAME),1,CHARINDEX('\', CONVERT(NVARCHAR(255), @@SERVERNAME))-1))

BEGIN
	exec('
	SELECT CAST(SERVERPROPERTY(''ProductVersion'') AS VARCHAR(15)) AS Version,
	''' + @MACHINE_NAME + ''' as machinename,
	''' + @ASSESSMENT_DATABSE_NAME + ''' as databasename,
	COALESCE(CONVERT(NVARCHAR(255), SERVERPROPERTY(''InstanceName'')), ''MSSQLSERVER'') as instancename,
	replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') as current_ts,
	''' + @MACHINE_NAME + ''' + ''_'' + ''' + @ASSESSMENT_DATABSE_NAME + ''' + ''_'' +  COALESCE(CONVERT(NVARCHAR(255), SERVERPROPERTY(''InstanceName'')), ''MSSQLSERVER'') + ''_'' + replace(convert(varchar, getdate(),1),''/'','''') + replace(convert(varchar, getdate(),108),'':'','''') as pkey');
END
