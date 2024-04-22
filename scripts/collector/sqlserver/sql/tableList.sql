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
set NOCOUNT on;

set LANGUAGE us_english;

declare @PKEY as VARCHAR(256);

declare @CLOUDTYPE as VARCHAR(256);

declare @ASSESSMENT_DATABASE_NAME as VARCHAR(256);

declare @PRODUCT_VERSION as INTEGER;

declare @validDB as INTEGER;

declare @DMA_SOURCE_ID as VARCHAR(256);

declare @DMA_MANUAL_ID as VARCHAR(256);

declare @CURRENT_DB_NAME as VARCHAR(256);

select @PKEY = N'$(pkey)';

select @CLOUDTYPE = 'NONE'
select @ASSESSMENT_DATABASE_NAME = N'$(database)';

select @PRODUCT_VERSION = convert(
		INTEGER,
		PARSENAME(
			convert(nvarchar, SERVERPROPERTY('productversion')),
			4
		)
	);

select @validDB = 0;

select @DMA_SOURCE_ID = N'$(dmaSourceId)';

select @DMA_MANUAL_ID = N'$(dmaManualId)';

select @CURRENT_DB_NAME = db_name();

if @ASSESSMENT_DATABASE_NAME = 'all'
select @ASSESSMENT_DATABASE_NAME = '%' if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE' begin begin
select @validDB = count(1)
from sys.databases
where name not in (
		'master',
		'model',
		'msdb',
		'distribution',
		'reportserver',
		'reportservertempdb',
		'resource',
		'rdsadmin'
	)
	and name like @ASSESSMENT_DATABASE_NAME
	and state = 0
end;

begin TRY if @PRODUCT_VERSION > 12
and @validDB <> 0
and @CLOUDTYPE = 'NONE'
and @CURRENT_DB_NAME <> 'tempdb' begin exec (
	'
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
						,[partition_type] = ISNULL(pf.type_desc,''NONE'')
						,[is_temp_table] = ''0''
					FROM sys.schemas s WITH (NOLOCK)
					JOIN sys.tables  t WITH (NOLOCK) ON (s.schema_id = t.schema_id)
					JOIN sys.indexes i WITH (NOLOCK) ON (t.object_id = i.object_id)
					JOIN (
						SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
						FROM sys.partitions WITH (NOLOCK)
						GROUP BY [object_id], [index_id]
					) p ON (i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id])
					JOIN (
						SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
						FROM sys.partitions p WITH (NOLOCK)
						JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
						GROUP BY p.[object_id], p.[index_id]
					) au ON (i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id])
					LEFT JOIN sys.partition_schemes ps WITH (NOLOCK) on (ps.data_space_id = i.data_space_id)
					LEFT JOIN sys.partition_functions pf WITH (NOLOCK) on (pf.function_id = ps.function_id)
					WHERE t.is_ms_shipped = 0 -- Not a system table
						AND i.type IN (0,1,5))
					SELECT 
						''"' + @PKEY + '"'' AS pkey,
						QUOTENAME(DB_NAME(), ''"'') as database_name,
						QUOTENAME(schema_name, ''"'') as schema_name,
						QUOTENAME(table_name, ''"'') as table_name,
						QUOTENAME(partition_count, ''"'') as partition_count,
						QUOTENAME(is_memory_optimized, ''"'') as is_memory_optimized,
						QUOTENAME(temporal_type, ''"'') as temporal_type,
						QUOTENAME(is_external, ''"'') as is_external,
						QUOTENAME(lock_escalation, ''"'') as lock_escalation,
						QUOTENAME(is_tracked_by_cdc, ''"'') as is_tracked_by_cdc,
						QUOTENAME(text_in_row_limit, ''"'') as text_in_row_limit,
						QUOTENAME(is_replicated, ''"'') as is_replicated,
						QUOTENAME(row_count, ''"'') as row_count,
						QUOTENAME(data_compression, ''"'') as data_compression,
						QUOTENAME(total_space_mb, ''"'') as total_space_mb,
						QUOTENAME(used_space_mb, ''"'') as used_space_mb,
						QUOTENAME(unused_space_mb, ''"'') as unused_space_mb,
						''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        				''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
						QUOTENAME(partition_type, ''"'') as partition_type,
						QUOTENAME(is_temp_table, ''"'') as is_temp_table
					FROM TableData');
	END;
	IF @PRODUCT_VERSION > 12 AND @validDB <> 0 AND @CLOUDTYPE = 'NONE' AND @CURRENT_DB_NAME = 'tempdb'
	BEGIN
		exec('WITH TableData AS (
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
						,[partition_type] = ISNULL(pf.type_desc,''NONE'')
						,[is_temp_table] = ''1''
					FROM sys.schemas s WITH (NOLOCK)
					JOIN sys.tables  t WITH (NOLOCK) ON (s.schema_id = t.schema_id)
					JOIN sys.indexes i WITH (NOLOCK) ON (t.object_id = i.object_id)
					JOIN (
						SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
						FROM sys.partitions WITH (NOLOCK)
						GROUP BY [object_id], [index_id]
					) p ON (i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id])
					JOIN (
						SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
						FROM sys.partitions p WITH (NOLOCK)
						JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
						GROUP BY p.[object_id], p.[index_id]
					) au ON (i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id])
					LEFT JOIN sys.partition_schemes ps WITH (NOLOCK) on (ps.data_space_id = i.data_space_id)
					LEFT JOIN sys.partition_functions pf WITH (NOLOCK) on (pf.function_id = ps.function_id)
					WHERE t.is_ms_shipped = 0 -- Not a system table
						AND i.type IN (0,1,5)
						AND (t.name LIKE N''##%''
							OR t.name like N''#%[_]%''
							AND t.name not like N''#[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]''))
					SELECT
						''"' + @PKEY + '"'' AS pkey,
						QUOTENAME(DB_NAME(), ''"'') as database_name,
						QUOTENAME(schema_name, ''"'') as schema_name,
						QUOTENAME(table_name, ''"'') as table_name,
						QUOTENAME(partition_count, ''"'') as partition_count,
						QUOTENAME(is_memory_optimized, ''"'') as is_memory_optimized,
						QUOTENAME(temporal_type, ''"'') as temporal_type,
						QUOTENAME(is_external, ''"'') as is_external,
						QUOTENAME(lock_escalation, ''"'') as lock_escalation,
						QUOTENAME(is_tracked_by_cdc, ''"'') as is_tracked_by_cdc,
						QUOTENAME(text_in_row_limit, ''"'') as text_in_row_limit,
						QUOTENAME(is_replicated, ''"'') as is_replicated,
						QUOTENAME(row_count, ''"'') as row_count,
						QUOTENAME(data_compression, ''"'') as data_compression,
						QUOTENAME(total_space_mb, ''"'') as total_space_mb,
						QUOTENAME(used_space_mb, ''"'') as used_space_mb,
						QUOTENAME(unused_space_mb, ''"'') as unused_space_mb,
						''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        				''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
						QUOTENAME(partition_type, ''"'') as partition_type,
						QUOTENAME(is_temp_table, ''"'') as is_temp_table
					FROM TableData');
	END;
	IF @PRODUCT_VERSION <= 12 AND @validDB <> 0 AND @CLOUDTYPE = 'NONE' AND @CURRENT_DB_NAME <> 'tempdb'
	BEGIN
		exec ('
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
					,[partition_type] = ISNULL(pf.type_desc,''NONE'')
					,[is_temp_table] = ''0''
				FROM sys.schemas s WITH (NOLOCK)
				JOIN sys.tables  t WITH (NOLOCK) ON (s.schema_id = t.schema_id)
				JOIN sys.indexes i WITH (NOLOCK) ON (t.object_id = i.object_id)
				LEFT JOIN (
					SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
					FROM sys.partitions WITH (NOLOCK)
					GROUP BY [object_id], [index_id]
				) p ON (i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id])
				LEFT JOIN (
					SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
					FROM sys.partitions p WITH (NOLOCK)
					JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
					GROUP BY p.[object_id], p.[index_id]
				) au ON (i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id])
				LEFT JOIN sys.partition_schemes ps WITH (NOLOCK) on (ps.data_space_id = i.data_space_id)
				LEFT JOIN sys.partition_functions pf WITH (NOLOCK) on (pf.function_id = ps.function_id)
				WHERE t.is_ms_shipped = 0 -- Not a system table
					AND i.type IN (0,1,5))
				SELECT
					''"' + @PKEY + '"'' AS pkey,
					QUOTENAME(DB_NAME(), ''"'') as database_name,
					QUOTENAME(schema_name, ''"'') as schema_name,
					QUOTENAME(table_name, ''"'') as table_name,
					QUOTENAME(partition_count, ''"'') as partition_count,
					QUOTENAME(is_memory_optimized, ''"'') as is_memory_optimized,
					QUOTENAME(temporal_type, ''"'') as temporal_type,
					QUOTENAME(is_external, ''"'') as is_external,
					QUOTENAME(lock_escalation, ''"'') as lock_escalation,
					QUOTENAME(is_tracked_by_cdc, ''"'') as is_tracked_by_cdc,
					QUOTENAME(text_in_row_limit, ''"'') as text_in_row_limit,
					QUOTENAME(is_replicated, ''"'') as is_replicated,
					QUOTENAME(row_count, ''"'') as row_count,
					QUOTENAME(data_compression, ''"'') as data_compression,
					QUOTENAME(total_space_mb, ''"'') as total_space_mb,
					QUOTENAME(used_space_mb, ''"'') as used_space_mb,
					QUOTENAME(unused_space_mb, ''"'') as unused_space_mb,
					''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        			''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
					QUOTENAME(partition_type, ''"'') as partition_type,
					QUOTENAME(is_temp_table, ''"'') as is_temp_table
				FROM TableData');
	END;
	IF @PRODUCT_VERSION <= 12 AND @validDB <> 0 AND @CLOUDTYPE = 'NONE' AND @CURRENT_DB_NAME = 'tempdb'
	BEGIN
		exec ('
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
					,[partition_type] = ISNULL(pf.type_desc,''NONE'')
					,[is_temp_table] = ''1''
				FROM sys.schemas s WITH (NOLOCK)
				JOIN sys.tables  t WITH (NOLOCK) ON (s.schema_id = t.schema_id)
				JOIN sys.indexes i WITH (NOLOCK) ON (t.object_id = i.object_id)
				LEFT JOIN (
					SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
					FROM sys.partitions WITH (NOLOCK)
					GROUP BY [object_id], [index_id]
				) p ON (i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id])
				LEFT JOIN (
					SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
					FROM sys.partitions p WITH (NOLOCK)
					JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
					GROUP BY p.[object_id], p.[index_id]
				) au ON (i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id])
				LEFT JOIN sys.partition_schemes ps WITH (NOLOCK) on (ps.data_space_id = i.data_space_id)
				LEFT JOIN sys.partition_functions pf WITH (NOLOCK) on (pf.function_id = ps.function_id)
				WHERE t.is_ms_shipped = 0 -- Not a system table
					AND i.type IN (0,1,5)
					AND (t.name LIKE N''##%''
							OR t.name like N''#%[_]%''
							AND t.name not like N''#[0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z][0-9A-Z]''))
				SELECT
					''"' + @PKEY + '"'' AS pkey,
					QUOTENAME(DB_NAME(), ''"'') as database_name,
					QUOTENAME(schema_name, ''"'') as schema_name,
					QUOTENAME(table_name, ''"'') as table_name,
					QUOTENAME(partition_count, ''"'') as partition_count,
					QUOTENAME(is_memory_optimized, ''"'') as is_memory_optimized,
					QUOTENAME(temporal_type, ''"'') as temporal_type,
					QUOTENAME(is_external, ''"'') as is_external,
					QUOTENAME(lock_escalation, ''"'') as lock_escalation,
					QUOTENAME(is_tracked_by_cdc, ''"'') as is_tracked_by_cdc,
					QUOTENAME(text_in_row_limit, ''"'') as text_in_row_limit,
					QUOTENAME(is_replicated, ''"'') as is_replicated,
					QUOTENAME(row_count, ''"'') as row_count,
					QUOTENAME(data_compression, ''"'') as data_compression,
					QUOTENAME(total_space_mb, ''"'') as total_space_mb,
					QUOTENAME(used_space_mb, ''"'') as used_space_mb,
					QUOTENAME(unused_space_mb, ''"'') as unused_space_mb,
					''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        			''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
					QUOTENAME(partition_type, ''"'') as partition_type,
					QUOTENAME(is_temp_table, ''"'') as is_temp_table
				FROM TableData');
	END;
	IF @PRODUCT_VERSION >= 12 AND @validDB <> 0 AND @CLOUDTYPE = 'AZURE' AND @CURRENT_DB_NAME <> 'tempdb'
    BEGIN
		exec ('
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
				,[partition_type] = ISNULL(pf.type_desc,''NONE'')
				,[is_temp_table] = ''0''
			FROM sys.schemas s WITH (NOLOCK)
			JOIN sys.tables  t WITH (NOLOCK) ON (s.schema_id = t.schema_id)
			JOIN sys.indexes i WITH (NOLOCK) ON (t.object_id = i.object_id)
			LEFT JOIN (
				SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
				FROM sys.partitions WITH (NOLOCK)
				GROUP BY [object_id], [index_id]
			) p ON (i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id])
			LEFT JOIN (
				SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
				FROM sys.partitions p WITH (NOLOCK)
				JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
				GROUP BY p.[object_id], p.[index_id]
			) au ON (i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id])
			LEFT JOIN sys.partition_schemes ps WITH (NOLOCK) on (ps.data_space_id = i.data_space_id)
			LEFT JOIN sys.partition_functions pf WITH (NOLOCK) on (pf.function_id = ps.function_id)
			WHERE t.is_ms_shipped = 0 -- Not a system table
				AND i.type IN (0,1,5))
			SELECT
				''"' + @PKEY + '"'' AS pkey,
				QUOTENAME(DB_NAME(), ''"'') as database_name,
				QUOTENAME(schema_name, ''"'') as schema_name,
				QUOTENAME(table_name, ''"'') as table_name,
				QUOTENAME(partition_count, ''"'') as partition_count,
				QUOTENAME(is_memory_optimized, ''"'') as is_memory_optimized,
				QUOTENAME(temporal_type, ''"'') as temporal_type,
				QUOTENAME(is_external, ''"'') as is_external,
				QUOTENAME(lock_escalation, ''"'') as lock_escalation,
				QUOTENAME(is_tracked_by_cdc, ''"'') as is_tracked_by_cdc,
				QUOTENAME(text_in_row_limit, ''"'') as text_in_row_limit,
				QUOTENAME(is_replicated, ''"'') as is_replicated,
				QUOTENAME(row_count, ''"'') as row_count,
				QUOTENAME(data_compression, ''"'') as data_compression,
				QUOTENAME(total_space_mb, ''"'') as total_space_mb,
				QUOTENAME(used_space_mb, ''"'') as used_space_mb,
				QUOTENAME(unused_space_mb, ''"'') as unused_space_mb,
				''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        		''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
				QUOTENAME(partition_type, ''"'') as partition_type,
				QUOTENAME(is_temp_table, ''"'') as is_temp_table
			FROM TableData');
	END;
	IF @PRODUCT_VERSION >= 12 AND @validDB <> 0 AND @CLOUDTYPE = 'AZURE' AND @CURRENT_DB_NAME = 'tempdb'
	BEGIN
		exec ('
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
				,[partition_type] = ISNULL(pf.type_desc,''NONE'')
				,[is_temp_table] = ''1''
			FROM sys.schemas s WITH (NOLOCK)
			JOIN sys.tables  t WITH (NOLOCK) ON (s.schema_id = t.schema_id)
			JOIN sys.indexes i WITH (NOLOCK) ON (t.object_id = i.object_id)
			LEFT JOIN (
				SELECT [object_id], index_id, partition_count=count(*), [rows]=sum([rows]), data_compression_cnt=count(distinct [data_compression])
				FROM sys.partitions WITH (NOLOCK)
				GROUP BY [object_id], [index_id]
			) p ON (i.[object_id] = p.[object_id] AND i.[index_id] = p.[index_id])
			LEFT JOIN (
				SELECT p.[object_id], p.[index_id], total_pages = sum(a.total_pages), used_pages = sum(a.used_pages), data_pages=sum(a.data_pages)
				FROM sys.partitions p WITH (NOLOCK)
				JOIN sys.allocation_units a ON p.[partition_id] = a.[container_id]
				GROUP BY p.[object_id], p.[index_id]
			) au ON (i.[object_id] = au.[object_id] AND i.[index_id] = au.[index_id])
			LEFT JOIN sys.partition_schemes ps WITH (NOLOCK) on (ps.data_space_id = i.data_space_id)
			LEFT JOIN sys.partition_functions pf WITH (NOLOCK) on (pf.function_id = ps.function_id)
			WHERE t.is_ms_shipped = 0 -- Not a system table
				AND i.type IN (0,1,5))
			SELECT
				''"' + @PKEY + '"'' AS pkey,
				QUOTENAME(DB_NAME(), ''"'') as database_name,
				QUOTENAME(schema_name, ''"'') as schema_name,
				QUOTENAME(table_name, ''"'') as table_name,
				QUOTENAME(partition_count, ''"'') as partition_count,
				QUOTENAME(is_memory_optimized, ''"'') as is_memory_optimized,
				QUOTENAME(temporal_type, ''"'') as temporal_type,
				QUOTENAME(is_external, ''"'') as is_external,
				QUOTENAME(lock_escalation, ''"'') as lock_escalation,
				QUOTENAME(is_tracked_by_cdc, ''"'') as is_tracked_by_cdc,
				QUOTENAME(text_in_row_limit, ''"'') as text_in_row_limit,
				QUOTENAME(is_replicated, ''"'') as is_replicated,
				QUOTENAME(row_count, ''"'') as row_count,
				QUOTENAME(data_compression, ''"'') as data_compression,
				QUOTENAME(total_space_mb, ''"'') as total_space_mb,
				QUOTENAME(used_space_mb, ''"'') as used_space_mb,
				QUOTENAME(unused_space_mb, ''"'') as unused_space_mb,
				''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
        		''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
				QUOTENAME(partition_type, ''"'') as partition_type,
				QUOTENAME(is_temp_table, ''"'') as is_temp_table
			FROM TableData');
	END;
	END TRY
   	BEGIN CATCH
	SELECT
		host_name() as host_name,
		db_name() as database_name,
		'tableList' as module_name,
		SUBSTRING(CONVERT(nvarchar,ERROR_NUMBER()),1,254) as error_number,
		SUBSTRING(CONVERT(nvarchar,ERROR_SEVERITY()),1,254) as error_severity,
		SUBSTRING(CONVERT(nvarchar,ERROR_STATE()),1,254) as error_state,
		SUBSTRING(CONVERT(nvarchar,ERROR_MESSAGE()),1,512) as error_message;
	END CATCH

end;

end TRY begin CATCH
select host_name() as host_name,
	db_name() as database_name,
	'tableList' as module_name,
	SUBSTRING(convert(nvarchar, ERROR_NUMBER()), 1, 254) as error_number,
	SUBSTRING(convert(nvarchar, ERROR_SEVERITY()), 1, 254) as error_severity,
	SUBSTRING(convert(nvarchar, ERROR_STATE()), 1, 254) as error_state,
	SUBSTRING(convert(nvarchar, ERROR_MESSAGE()), 1, 512) as error_message;

end CATCH
end;
