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
SELECT @PKEY = N'$(pkey)';
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'
DECLARE @PRODUCT_VERSION AS INTEGER
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));

SELECT
    @PKEY as PKEY, sizing.*
FROM(
SELECT
	DB_NAME(database_id) AS database_name, 
    type_desc, 
    SUM(size/128.0) AS current_size_mb
FROM sys.master_files sm
WHERE DB_NAME(database_id) NOT IN ('master', 'model', 'msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND type IN (0,1)
AND EXISTS (SELECT 1 FROM MASTER.sys.databases sd WHERE state = 0 
AND sd.name NOT IN ('master','model','msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND sd.name like @ASSESSMENT_DATABSE_NAME
AND sd.state = 0
AND DB_NAME(sd.database_id) = DB_NAME(sm.database_id))
GROUP BY DB_NAME(database_id), type_desc) sizing