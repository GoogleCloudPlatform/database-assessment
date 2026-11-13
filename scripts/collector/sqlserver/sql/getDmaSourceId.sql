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

DECLARE @MACHINE_NAME AS VARCHAR(256)
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @DBNAME AS VARCHAR(256)

SELECT @CLOUDTYPE = 'NONE'
SELECT @DBNAME = 'msdb'
IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE', @DBNAME = 'master';

/* Azure SQL Database (EngineEdition 5) is collected one database at a time: identify the connected
   database rather than the logical server's master so each collected database is its own source. */
IF @CLOUDTYPE = 'AZURE' AND CONVERT(INT, SERVERPROPERTY('EngineEdition')) = 5 AND DB_NAME() <> 'master'
	SELECT @DBNAME = DB_NAME();

DECLARE @SERVER_NAME AS NVARCHAR(256)
SELECT @SERVER_NAME = COALESCE(NULLIF(CONVERT(NVARCHAR(255), @@SERVERNAME), N''), CONVERT(NVARCHAR(255), SERVERPROPERTY('MachineName')), CONVERT(NVARCHAR(255), HOST_NAME()), N'UNKNOWN');

IF CHARINDEX('\', @SERVER_NAME)-1 = -1
  SELECT @MACHINE_NAME = UPPER(@SERVER_NAME)
ELSE
  SELECT @MACHINE_NAME = UPPER(SUBSTRING(@SERVER_NAME, 1, CHARINDEX('\', @SERVER_NAME)-1))
SELECT @MACHINE_NAME + '_' + replace(service_broker_guid,'-','') + '_' + COALESCE(CONVERT(NVARCHAR(255), SERVERPROPERTY('InstanceName')), 'MSSQLSERVER')
FROM sys.databases
WHERE name = @DBNAME;
