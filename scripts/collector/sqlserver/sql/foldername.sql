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
set NOCOUNT on;

set LANGUAGE us_english;

declare @ASSESSMENT_DATABASE_NAME as VARCHAR(256)
declare @MACHINE_NAME as VARCHAR(256)
select @ASSESSMENT_DATABASE_NAME = N'$(database)';

if @ASSESSMENT_DATABASE_NAME = 'all'
select @ASSESSMENT_DATABASE_NAME = 'master' if CHARINDEX(
		'\', @@SERVERNAME)-1 = -1
  SELECT @MACHINE_NAME = UPPER(@@SERVERNAME)
ELSE
  SELECT @MACHINE_NAME = UPPER(SUBSTRING(CONVERT(nvarchar, @@SERVERNAME),1,CHARINDEX(' \ ', CONVERT(nvarchar, @@SERVERNAME))-1))

BEGIN
	exec('
		select CAST(
				SERVERPROPERTY('' ProductVersion '') as VARCHAR(15)
			) as Version,
			''' + @MACHINE_NAME + ''' as machinename,
			''' + @ASSESSMENT_DATABASE_NAME + ''' as databasename,
			COALESCE(
				convert(nvarchar, SERVERPROPERTY('' InstanceName '')),
				'' MSSQLSERVER ''
			) as instancename,
			replace(convert(varchar, getdate(), 1), '' / '', '''') + replace(convert(varchar, getdate(), 108), '' :'', '''') as current_ts,
			''' + @MACHINE_NAME + ''' + '' _ '' + ''' + @ASSESSMENT_DATABASE_NAME + ''' + '' _ '' + COALESCE(
				convert(nvarchar, SERVERPROPERTY('' InstanceName '')),
				'' MSSQLSERVER ''
			) + '' _ '' + replace(convert(varchar, getdate(), 1), '' / '', '''') + replace(convert(varchar, getdate(), 108), '' :'', '''') as pkey ');
END
