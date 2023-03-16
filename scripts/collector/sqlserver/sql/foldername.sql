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

This script access Automatic Repository Workload (AWR) views in the database dictionary.
Please ensure you have proper licensing. For more information consult Oracle Support Doc ID 1490798.1

*/

SET NOCOUNT ON;
SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(15)) AS Version, 
CAST(SERVERPROPERTY('MachineName') AS VARCHAR(15)) as machinename, 
'master'as databasename, 
@@ServiceName as instancename, 
FORMAT(GETDATE() , 'MMddyyHHmmss') as current_ts,
@@SERVERNAME + '_' + 'master' + '_' + @@ServiceName + '_' + FORMAT(GETDATE() , 'MMddyyHHmmss') as pkey;