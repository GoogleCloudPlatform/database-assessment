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

SET NOCOUNT ON;
SET LANGUAGE us_english;
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
DECLARE @HASDBACCESS AS TINYINT

SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @HASDBACCESS = N'$(hasdbaccess)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

SELECT name
FROM sys.databases
WHERE name NOT IN ('master','model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin','SSISDB','DWDiagnostics','DWConfiguration','DWQueue', 'DQS_STAGING_DATA')
    AND name like @ASSESSMENT_DATABSE_NAME
    AND state = 0
    AND HAS_DBACCESS(name) = @HASDBACCESS
