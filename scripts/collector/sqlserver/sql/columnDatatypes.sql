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
DECLARE @PRODUCT_VERSION AS VARCHAR(30)
SELECT @PRODUCT_VERSION = PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4);
DECLARE @dbname VARCHAR(50)
DECLARE db_cursor CURSOR FOR 
SELECT name 
FROM MASTER.dbo.sysdatabases 
WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')

IF OBJECT_ID('tempdb..#columnDatatypes') IS NOT NULL  
   DROP TABLE #columnDatatypes;

CREATE TABLE #columnDatatypes(
   database_name nvarchar(255) DEFAULT db_name()
   ,schema_name nvarchar(255)
   ,table_name nvarchar(255)
   ,datatype nvarchar(255)
   ,max_length nvarchar(255)
   ,precision nvarchar(255)
   ,scale nvarchar(255)
   ,is_computed nvarchar(10)
   ,is_filestream nvarchar(10)
   ,is_masked nvarchar(10)
   ,encryption_type nvarchar(10)
   ,is_sparse nvarchar(10)
   ,rule_object_id nvarchar(255)
   ,column_count nvarchar(255)
   );

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0
BEGIN
   IF @PRODUCT_VERSION > 12
   BEGIN
	exec ('
	use [' + @dbname + '];
	INSERT INTO #columnDatatypes (
      schema_name
      ,table_name
      ,datatype
      ,max_length
      ,precision
      ,scale
      ,is_computed
      ,is_filestream
      ,is_masked
      ,encryption_type
      ,is_sparse
      ,rule_object_id
      ,column_count 
   )
   SELECT s.name AS schema_name
         , o.name AS table_name
         , t.name AS datatype
         , c.max_length
         , c.precision
         , c.scale
         , c.is_computed
         , c.is_filestream
         , c.is_masked
         , ISNULL(c.encryption_type,0) AS encryption_type
         , c.is_sparse
         , c.rule_object_id
         , count(1) column_count
      FROM  sys.objects o 
      JOIN  sys.schemas s
         ON  s.schema_id = o.schema_id
      JOIN  sys.columns c
      ON  o.object_id = c.object_id
      JOIN  sys.types t
      ON  t.system_type_id = c.system_type_id AND t.user_type_id = c.user_type_id
   WHERE o.type_desc = ''USER_TABLE'' 
      AND t.system_type_id = t.user_type_id
   GROUP BY s.name
         , o.name
         , t.name
         , c.max_length
         , c.precision
         , c.scale
         , c.is_computed
         , c.is_filestream
         , c.is_masked
         , c.encryption_type
         , c.is_sparse
         , c.rule_object_id
   ORDER BY s.name
         , o.name
         , t.name');
   END;
   IF @PRODUCT_VERSION <= 12
   BEGIN
	exec ('
	use [' + @dbname + '];
	INSERT INTO #columnDatatypes (
      schema_name
      ,table_name
      ,datatype
      ,max_length
      ,precision
      ,scale
      ,is_computed
      ,is_filestream
      ,is_masked
      ,encryption_type
      ,is_sparse
      ,rule_object_id
      ,column_count 
   )
   SELECT s.name AS schema_name
         , o.name AS table_name
         , t.name AS datatype
         , c.max_length
         , c.precision
         , c.scale
         , c.is_computed
         , c.is_filestream
         , 0 as is_masked
         , 0 AS encryption_type
         , c.is_sparse
         , c.rule_object_id
         , count(1) column_count
      FROM  sys.objects o 
      JOIN  sys.schemas s
         ON  s.schema_id = o.schema_id
      JOIN  sys.columns c
      ON  o.object_id = c.object_id
      JOIN  sys.types t
      ON  t.system_type_id = c.system_type_id AND t.user_type_id = c.user_type_id
   WHERE o.type_desc = ''USER_TABLE'' 
      AND t.system_type_id = t.user_type_id
   GROUP BY s.name
         , o.name
         , t.name
         , c.max_length
         , c.precision
         , c.scale
         , c.is_computed
         , c.is_filestream
         , c.is_sparse
         , c.rule_object_id
   ORDER BY s.name
         , o.name
         , t.name');
   END;
   FETCH NEXT FROM db_cursor INTO @dbname 
END

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #columnDatatypes a;

DROP TABLE #columnDatatypes;