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
    ,object_name nvarchar(255)
    ,object_type nvarchar(255)
    ,object_type_desc nvarchar(255)
    ,object_count nvarchar(255)
    ,lines_of_code nvarchar(255)
	,associated_table_name nvarchar(255));

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0  
BEGIN
	exec ('
	use [' + @dbname + '];
	INSERT INTO #objectList
    SELECT 
    database_name 
    , schema_name
	, NameOfObject as object_name
    , RTRIM(LTRIM(type)) as type
    , type_desc
	, count(*) AS object_count
    , ISNULL(SUM(LinesOfCode),0) AS lines_of_code
	, associated_table_name
    FROM 
    (
    SELECT
    DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(o.type)) as type, 
    o.type_desc, 
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode, 
    OBJECT_NAME(o.object_id) AS NameOfObject ,
    NULL as associated_table_name
    FROM 
    sys.objects o
    JOIN sys.schemas s ON s.schema_id = o.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = o.object_id
    WHERE 
    o.type NOT IN (
        ''S'' --SYSTEM_TABLE
        , 
        ''IT'' --INTERNAL_TABLE
        ,
        ''F'' --FOREIGN KEY
        ,
        ''PK''  --PRIMARY KEY
        ,
        ''C''  -- CHECK CONSTRAINT
        ,
        ''D''  --DEFAULT CONSTRAINT
        ,
        ''UQ''  --UNIQUE CONSTRAINT
        ,
        ''TR'' --TRIGGER
        ,
        ''V'' --VIEW
        ) 
    AND OBJECTPROPERTY(o.object_id, ''IsMSShipped'') = 0
    UNION
    select DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(type)) as type,
    type_desc,
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode,
    cc.name AS NameOfObject ,
    object_name(cc.parent_object_id) AS associated_table_name
    from sys.check_constraints cc
    JOIN sys.schemas s ON s.schema_id = cc.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = cc.object_id
    WHERE cc.is_ms_shipped = 0
    UNION
    select DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(type)) as type,
    type_desc,
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode,
    fk.name AS NameOfObject ,
    object_name(fk.parent_object_id) AS associated_table_name
    from sys.foreign_keys fk
    JOIN sys.schemas s ON s.schema_id = fk.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = fk.object_id
    WHERE fk.is_ms_shipped = 0
    UNION
    select DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(type)) as type,
    type_desc,
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode,
    dc.name AS NameOfObject ,
    object_name(dc.parent_object_id) AS associated_table_name
    from sys.default_constraints dc
    JOIN sys.schemas s ON s.schema_id = dc.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = dc.object_id
    WHERE dc.is_ms_shipped = 0
    UNION
    select DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(type)) as type,
    type_desc,
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode,
    kc.name AS NameOfObject,
    object_name(kc.parent_object_id) AS associated_table_name
    from sys.key_constraints kc
    JOIN sys.schemas s ON s.schema_id = kc.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = kc.object_id
    WHERE kc.is_ms_shipped = 0
    UNION
    select DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(t.type)) as type,
    t.type_desc,
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode,
    t.name AS NameOfObject ,
    object_name(t.parent_id) AS associated_table_name
    from sys.triggers t
    JOIN sys.tables tbl ON tbl.object_id = t.parent_id
    LEFT OUTER JOIN sys.schemas s ON s.schema_id = tbl.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = t.object_id
    WHERE t.is_ms_shipped = 0
    UNION
    select DB_NAME(DB_ID()) as database_name,
    s.name as schema_name,
    RTRIM(LTRIM(type)) as type,
    type_desc,
    ISNULL(LEN(a.definition)- LEN(
        REPLACE(
        a.definition, 
        CHAR(10), 
        ''''
        )
    ),0) AS LinesOfCode,
    v.name AS NameOfObject ,
    NULL as associated_table_name
    from sys.views v
    JOIN sys.schemas s ON s.schema_id = v.schema_id
    LEFT OUTER JOIN sys.all_sql_modules a ON a.OBJECT_ID = v.object_id
    WHERE v.is_ms_shipped = 0
    ) SubQuery 
        GROUP BY 
        database_name,
        schema_name,
        NameOfObject,
        type, 
        type_desc,
        associated_table_name
    ORDER BY database_name, schema_name, associated_table_name');
    FETCH NEXT FROM db_cursor INTO @dbname 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #objectList a ORDER BY database_name, schema_name, object_type;

IF OBJECT_ID('tempdb..#objectList') IS NOT NULL  
   DROP TABLE #objectList;