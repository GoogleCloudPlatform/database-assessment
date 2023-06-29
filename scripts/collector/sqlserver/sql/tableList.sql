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
DECLARE @PRODUCT_VERSION AS INTEGER
SELECT @PRODUCT_VERSION = CONVERT(integer, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
DECLARE @dbname VARCHAR(50)
DECLARE db_cursor CURSOR FOR 
SELECT name
FROM MASTER.sys.databases 
WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND state = 0

IF OBJECT_ID('tempdb..#tableList') IS NOT NULL  
   DROP TABLE #tableList;

CREATE TABLE #tableList(
	database_name nvarchar(255)
    ,schema_name nvarchar(255)
    ,table_name nvarchar(255)
    ,partition_count nvarchar(10)
	,is_memory_optimized nvarchar(10)
	,temporal_type nvarchar(10)
	,is_external nvarchar(10)
	,lock_escalation nvarchar(10)
	,is_tracked_by_cdc nvarchar(10)
	,text_in_row_limit nvarchar(10)
	,is_replicated nvarchar(10)
    ,row_count nvarchar(255)
    ,data_compression nvarchar(255)
    ,total_space_mb nvarchar(255)
    ,used_space_mb nvarchar(255)
    ,unused_space_mb nvarchar(255)
    );

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0  
BEGIN
	IF @PRODUCT_VERSION > 12
	BEGIN
	exec ('
	use [' + @dbname + '];
	WITH TableData AS (
		SELECT 
			[schema_name]      = s.[name]
			,[table_name]       = t.[name]
			,[index_name]       = CASE WHEN i.[type] in (0,1,5) THEN null    ELSE i.[name] END -- 0=Heap; 1=Clustered; 5=Clustered Columnstore
			,[object_type]      = CASE WHEN i.[type] in (0,1,5) THEN ''TABLE'' ELSE ''INDEX''  END
			,[index_type]       = i.[type_desc]
			,[partition_count]  = p.partition_count
			,[is_memory_optimized]  = t.is_memory_optimized
			,[temporal_type]  = t.temporal_type
			,[is_external]  = t.is_external
			,[lock_escalation] = t.lock_escalation
			,[is_tracked_by_cdc]  =  t.is_tracked_by_cdc
			,[text_in_row_limit]  =  t.text_in_row_limit
			,[is_replicated]  =  t.is_replicated
			,[row_count]        = p.[rows]
			,[data_compression] = CASE WHEN p.data_compression_cnt > 1 THEN ''Mixed''
									ELSE (  SELECT DISTINCT p.data_compression_desc
											FROM sys.partitions p
											WHERE i.[object_id] = p.[object_id] AND i.index_id = p.index_id
											)
								END
			,[total_space_mb]   = convert(nvarchar,(round(( au.total_pages                  * (8/1024.00)), 2)))
			,[used_space_mb]    = convert(nvarchar,(round(( au.used_pages                   * (8/1024.00)), 2)))
			,[unused_space_mb]  = convert(nvarchar,(round(((au.total_pages - au.used_pages) * (8/1024.00)), 2)))
		FROM sys.schemas s
		JOIN sys.tables  t ON s.schema_id = t.schema_id
		JOIN sys.indexes i ON t.object_id = i.object_id
		JOIN (
			SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
			FROM sys.partitions
			GROUP BY [object_id], [index_id]
		) p ON i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id]
		JOIN (
			SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
			FROM sys.partitions p
			JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
			GROUP BY p.[object_id], p.[index_id]
		) au ON i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id]
		WHERE t.is_ms_shipped = 0 -- Not a system table
			AND i.type IN (0,1,5))
		INSERT INTO #tableList
		SELECT 
			DB_NAME() as database_name,
			schema_name,
            table_name,
            partition_count,
			is_memory_optimized,
			temporal_type,
			is_external,
			lock_escalation,
			is_tracked_by_cdc,
			text_in_row_limit,
			is_replicated,
            row_count,
            data_compression,
            total_space_mb,
            used_space_mb,
            unused_space_mb
		FROM TableData');
	END;
	IF @PRODUCT_VERSION <= 12
	BEGIN
	exec ('
	use [' + @dbname + '];
	WITH TableData AS (
		SELECT 
			[schema_name]      = s.[name]
			,[table_name]       = t.[name]
			,[index_name]       = CASE WHEN i.[type] in (0,1,5) THEN null    ELSE i.[name] END -- 0=Heap; 1=Clustered; 5=Clustered Columnstore
			,[object_type]      = CASE WHEN i.[type] in (0,1,5) THEN ''TABLE'' ELSE ''INDEX''  END
			,[index_type]       = i.[type_desc]
			,[partition_count]  = p.partition_count
			,[is_memory_optimized]  = 0
			,[temporal_type]  = 0
			,[is_external]  = 0
			,[lock_escalation] = t.lock_escalation
			,[is_tracked_by_cdc]  =  t.is_tracked_by_cdc
			,[text_in_row_limit]  =  t.text_in_row_limit
			,[is_replicated]  =  t.is_replicated
			,[row_count]        = p.[rows]
			,[data_compression] = CASE WHEN p.data_compression_cnt > 1 THEN ''Mixed''
									ELSE (  SELECT DISTINCT p.data_compression_desc
											FROM sys.partitions p
											WHERE i.[object_id] = p.[object_id] AND i.index_id = p.index_id
											)
								END
			,[total_space_mb]   = convert(nvarchar,(round(( au.total_pages                  * (8/1024.00)), 2)))
			,[used_space_mb]    = convert(nvarchar,(round(( au.used_pages                   * (8/1024.00)), 2)))
			,[unused_space_mb]  = convert(nvarchar,(round(((au.total_pages - au.used_pages) * (8/1024.00)), 2)))
		FROM sys.schemas s
		JOIN sys.tables  t ON s.schema_id = t.schema_id
		JOIN sys.indexes i ON t.object_id = i.object_id
		JOIN (
			SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
			FROM sys.partitions
			GROUP BY [object_id], [index_id]
		) p ON i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id]
		JOIN (
			SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
			FROM sys.partitions p
			JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
			GROUP BY p.[object_id], p.[index_id]
		) au ON i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id]
		WHERE t.is_ms_shipped = 0 -- Not a system table
			AND i.type IN (0,1,5))
		INSERT INTO #tableList
		SELECT 
			DB_NAME() as database_name,
			schema_name,
            table_name,
            partition_count,
			is_memory_optimized,
			temporal_type,
			is_external,
			lock_escalation,
			is_tracked_by_cdc,
			text_in_row_limit,
			is_replicated,
            row_count,
            data_compression,
            total_space_mb,
            used_space_mb,
            unused_space_mb
		FROM TableData');
	END;
    FETCH NEXT FROM db_cursor INTO @dbname 
END 

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #tableList a ORDER BY database_name, schema_name, table_name;

DROP TABLE #tableList;