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
DECLARE @HASDBACCESS AS TINYINT
DECLARE @CLOUDTYPE AS VARCHAR(256)

SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @HASDBACCESS = N'$(hasdbaccess)';
SELECT @CLOUDTYPE = 'NONE'

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'


IF @CLOUDTYPE = 'NONE'
BEGIN
SELECT name
FROM sys.databases
WHERE name NOT IN ('master','model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin','SSISDB','DWDiagnostics','DWConfiguration','DWQueue', 'DQS_STAGING_DATA')
    AND name like @ASSESSMENT_DATABSE_NAME
    AND state = 0
    AND is_read_only = 0
    AND HAS_DBACCESS(name) = @HASDBACCESS;
END;
/* Execute the following statment to get the databases to run against */
IF @CLOUDTYPE = 'AZURE' AND @HASDBACCESS = '1'
BEGIN
    SELECT name
    FROM sys.databases
    WHERE name NOT IN ('master','model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin','SSISDB','DWDiagnostics','DWConfiguration','DWQueue', 'DQS_STAGING_DATA')
        AND name like @ASSESSMENT_DATABSE_NAME
        AND state = 0
        AND is_read_only = 0;
END;
/* Hard code NULL as in Azure the user should be able to log into all databases */
IF @CLOUDTYPE = 'AZURE' AND @HASDBACCESS = '0'
BEGIN
    SELECT '' name FROM sys.databases WHERE 1=2;
END;
