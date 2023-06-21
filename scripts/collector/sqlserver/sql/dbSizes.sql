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
SELECT
    N'$(pkey)' as PKEY, sizing.*
FROM(
SELECT
	DB_NAME(database_id) AS database_name, 
    type_desc, 
    SUM(size/128.0) AS current_size_mb
FROM sys.master_files
WHERE DB_NAME(database_id) NOT IN ('master', 'model', 'msdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND type IN (0,1)
GROUP BY DB_NAME(database_id), type_desc) sizing
ORDER BY 2
;