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
DECLARE @dbname VARCHAR(50)
DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM MASTER.dbo.sysdatabases 
WHERE name NOT IN ('master','model','msdb','tempdb')

IF OBJECT_ID('tempdb..#objectList') IS NOT NULL  
   DROP TABLE #objectList;

CREATE TABLE #objectList(
    database_name nvarchar(255)
    ,schema_name nvarchar(255)
    ,object_type nvarchar(255)
    ,object_type_desc nvarchar(255)
    ,object_count nvarchar(255)
    ,lines_of_code nvarchar(255));

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0  
BEGIN
	exec ('
	use [' + @dbname + '];
	INSERT INTO #objectList
    SELECT 
    DB_NAME(DB_ID()) as database_name 
    , schema_name
    , type 
    , type_desc
    , count(*) AS object_count
    , SUM(LinesOfCode) AS lines_of_code 
    FROM 
    (
        SELECT
        s.name as schema_name,
        TRIM(o.type) as type, 
        o.type_desc, 
        LEN(a.definition)- LEN(
            REPLACE(
            a.definition, 
            CHAR(10), 
            ''''
            )
        ) AS LinesOfCode, 
        OBJECT_NAME(o.object_id) AS NameOfObject 
        FROM 
        sys.all_sql_modules a 
        JOIN sys.objects o ON a.OBJECT_ID = o.object_id 
        JOIN sys.schemas s ON s.schema_id = o.schema_id 
        WHERE 
        o.type NOT IN (
            ''S'' --SYSTEM_TABLE
            , 
            ''U'' --USER_TABLE
            , 
            ''ET'' --EXTERNAL_TABLE
            , 
            ''IT'' --INTERNAL_TABLE
            ) 
        AND OBJECTPROPERTY(o.object_id, ''IsMSShipped'') = 0
    ) SubQuery 
    GROUP BY 
    schema_name,
    type, 
    type_desc');
    FETCH NEXT FROM db_cursor INTO @dbname 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #objectList a ORDER BY database_name, schema_name, object_type;

DROP TABLE #objectList;