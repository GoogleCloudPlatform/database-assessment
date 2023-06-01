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
SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(15)) AS Version, 
UPPER(CAST(SERVERPROPERTY('MachineName') AS VARCHAR(15))) as machinename, 
'master'as databasename, 
@@ServiceName as instancename, 
replace(convert(varchar, getdate(),1),'/','') + replace(convert(varchar, getdate(),108),':','') as current_ts,
UPPER(@@SERVERNAME) + '_' + 'master' + '_' + @@ServiceName + '_' + replace(convert(varchar, getdate(),1),'/','') + replace(convert(varchar, getdate(),108),':','') as pkey;