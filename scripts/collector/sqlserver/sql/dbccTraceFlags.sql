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

SET NOCOUNT ON
DECLARE @PKEY AS VARCHAR(256)
SELECT @PKEY = N'$(pkey)';

IF OBJECT_ID('tempdb..#dbccTraceTable') IS NOT NULL  
   DROP TABLE #dbccTraceTable;

CREATE TABLE #dbccTraceTable (
    [name] int, 
    [status] int, 
    [global] int, 
    [session] int
);

INSERT INTO #dbccTraceTable exec('dbcc tracestatus()')

SELECT @PKEY as PKEY, a.* from #dbccTraceTable a;

IF OBJECT_ID('tempdb..#dbccTraceTable') IS NOT NULL  
   DROP TABLE #dbccTraceTable;