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
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

SELECT count(1)
FROM sys.databases
WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND name like @ASSESSMENT_DATABSE_NAME
AND state = 0
AND is_read_only = 0;
