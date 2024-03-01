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

declare @PKEY as VARCHAR(256)
declare @CLOUDTYPE as VARCHAR(256)
declare @ASSESSMENT_DATABASE_NAME as VARCHAR(256)
declare @PRODUCT_VERSION as INTEGER
declare @validDB as INTEGER
declare @DMA_SOURCE_ID as VARCHAR(256)
declare @DMA_MANUAL_ID as VARCHAR(256)
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

if @ASSESSMENT_DATABASE_NAME = 'all'
select @ASSESSMENT_DATABASE_NAME = '%' if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE' if OBJECT_ID('tempdb..#indexList') is not null drop table #indexList;
   create table #indexList
   (
      database_name nvarchar(255),
      schema_name nvarchar(255),
      table_name nvarchar(255),
      index_name nvarchar(255),
      index_type nvarchar(255),
      is_primary_key nvarchar(10),
      is_unique nvarchar(10),
      fill_factor nvarchar(10),
      allow_page_locks nvarchar(10),
      has_filter nvarchar(10),
      data_compression nvarchar(10),
      data_compression_desc nvarchar(255),
      is_partitioned nvarchar(255),
      count_key_ordinal nvarchar(10),
      count_partition_ordinal nvarchar(10),
      count_is_included_column nvarchar(10),
      total_space_mb nvarchar(255),
      is_computed_index nvarchar(10),
      is_index_on_view nvarchar(10)
   );

begin begin
select @validDB = count(1)
from sys.databases
where name not in (
      'master',
      'model',
      'msdb',
      'tempdb',
      'distribution',
      'reportserver',
      'reportservertempdb',
      'resource',
      'rdsadmin'
   )
   and name like @ASSESSMENT_DATABASE_NAME
   and state = 0
end begin TRY if @validDB <> 0 begin exec (
   '
            WITH sys_schemas AS (
                 SELECT name, schema_id
                 FROM sys.schemas
            ),
            sys_views AS (
                SELECT v.*, s.name AS schema_name
                FROM sys.views v
                LEFT JOIN sys_schemas s ON v.schema_id = s.schema_id
            ),
			   index_computed_cols AS (
               SELECT distinct i.object_id, i.name as index_name, s.name as schema_name, t.name as table_name, 1 as is_computed_index
               FROM sys.indexes i
               JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
               JOIN sys.computed_columns cc ON ic.object_id = cc.object_id and ic.column_id = cc.column_id
               JOIN sys.objects o ON o.object_id = i.object_id AND o.is_ms_shipped = 0
               JOIN sys.tables t ON i.object_id = t.object_id AND t.is_ms_shipped = 0
               JOIN sys.schemas s ON s.schema_id = t.schema_id
            )
            INSERT INTO #indexList
            SELECT
               DB_NAME() as database_name
               ,CASE
	            WHEN s.name IS NULL THEN v.schema_name
		    ELSE s.name
	        END as schema_name
               ,CASE
                  WHEN t.name IS NULL THEN v.name
                  ELSE t.name
               END as table_name
               ,i.name as index_name
               ,i.type_desc as index_type
               ,i.is_primary_key
               ,i.is_unique
               ,i.fill_factor
               ,i.allow_page_locks
               ,i.has_filter
               ,ISNULL (p.data_compression,0) as data_compression
               ,ISNULL (p.data_compression_desc,''NONE'') as data_compression_desc
               ,ISNULL (ps.name, ''Not Partitioned'') as partition_scheme
               ,ISNULL (SUM(ic.key_ordinal),0) as count_key_ordinal
               ,ISNULL (SUM(ic.partition_ordinal),0) as count_partition_ordinal
               ,ISNULL (SUM(CONVERT(int,ic.is_included_column)),0) as count_is_included_column
               ,ISNULL (CONVERT(nvarchar, ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2)),0) as total_space_mb
               ,ISNULL (icc.is_computed_index,0) as is_computed_index
               ,CASE
                  WHEN v.name IS NOT NULL THEN ''1''
                  ELSE ''0''
               END as is_index_on_view
            FROM sys.indexes i
            JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            JOIN sys.objects o ON o.object_id = i.object_id AND o.is_ms_shipped = 0
            LEFT JOIN sys.tables t ON i.object_id = t.object_id AND t.is_ms_shipped = 0
            LEFT JOIN sys_views v ON i.object_id = v.object_id AND v.is_ms_shipped = 0
            LEFT JOIN sys_schemas s ON (s.schema_id = t.schema_id)
            LEFT JOIN sys.partitions AS p ON (p.object_id = i.object_id AND p.index_id = i.index_id)
            LEFT JOIN sys.allocation_units AS a ON (a.container_id = p.partition_id)
            LEFT JOIN sys.partition_schemes ps ON (i.data_space_id = ps.data_space_id)
            LEFT JOIN index_computed_cols icc ON (i.object_id = icc.object_id
                     and i.name = icc.index_name
                     and icc.table_name = t.name
                     and icc.schema_name = s.name)
	    WHERE i.NAME is not NULL
            GROUP BY
                CASE
	                 WHEN s.name IS NULL THEN v.schema_name
		              ELSE s.name
	             END
               ,CASE
                  WHEN t.name IS NULL THEN v.name
                  ELSE t.name
               END
               ,i.name
               ,i.type_desc
               ,i.is_primary_key
               ,i.is_unique
               ,i.fill_factor
               ,i.allow_page_locks
               ,i.has_filter
               ,ISNULL (p.data_compression,0)
               ,ISNULL (p.data_compression_desc,''NONE'')
               ,ISNULL (ps.name, ''Not Partitioned'')
               ,ISNULL (icc.is_computed_index,0)
               ,CASE
                  WHEN v.name IS NOT NULL THEN ''1''
                  ELSE ''0''
               END
       UNION
       SELECT
          DB_NAME() as database_name,
          s.name as schema_name,
          t.name as table_name,
          o.name as index_name,
          ''FULLTEXT'' as index_type,
          0 as is_primary_key,
          0 as is_unique,
          0 as fill_factor,
          0 as allow_page_locks,
          0 as has_filter,
          p.data_compression,
          p.data_compression_desc,
          ISNULL (ps.name, ''Not Partitioned'') as partition_scheme,
          0 as count_key_ordinal,
          0 as count_partition_ordinal,
          0 as count_is_included_column,
          CONVERT(nvarchar, ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2)) as total_space_mb,
          0 as is_computed_index,
          0 as is_index_on_view
       FROM sys.fulltext_indexes fi
          JOIN sys.objects o on (o.object_id = fi.object_id)
          JOIN sys.fulltext_index_columns ic ON fi.object_id = ic.object_id
          LEFT JOIN sys.tables t ON fi.object_id = t.object_id AND t.is_ms_shipped = 0
          LEFT JOIN sys_schemas s ON s.schema_id = t.schema_id
          LEFT JOIN sys.partitions AS p ON p.object_id = fi.object_id
          LEFT JOIN sys.allocation_units AS a ON a.container_id = p.partition_id
          LEFT JOIN sys.partition_schemes ps ON fi.data_space_id = ps.data_space_id
       GROUP BY
          s.name,
          t.name,
          o.name,
          p.data_compression,
          p.data_compression_desc,
          ISNULL (ps.name, ''Not Partitioned'')'
);

end;

end TRY begin CATCH
select host_name() as host_name,
   db_name() as database_name,
   'indexList' as module_name,
   SUBSTRING(convert(nvarchar, ERROR_NUMBER()), 1, 254) as error_number,
   SUBSTRING(convert(nvarchar, ERROR_SEVERITY()), 1, 254) as error_severity,
   SUBSTRING(convert(nvarchar, ERROR_STATE()), 1, 254) as error_state,
   SUBSTRING(convert(nvarchar, ERROR_MESSAGE()), 1, 512) as error_message;

end CATCH
end
select @PKEY as PKEY,
   a.database_name,
   a.schema_name,
   a.table_name,
   a.index_name,
   a.index_type,
   a.is_primary_key,
   a.is_unique,
   a.fill_factor,
   a.allow_page_locks,
   a.has_filter,
   a.data_compression,
   a.data_compression_desc,
   a.is_partitioned,
   a.count_key_ordinal,
   a.count_partition_ordinal,
   a.count_is_included_column,
   a.total_space_mb,
   @DMA_SOURCE_ID as dma_source_id,
   @DMA_MANUAL_ID as dma_manual_id,
   a.IS_COMPUTED_INDEX as is_computed_index,
   a.IS_INDEX_ON_VIEW as is_index_on_view
from #indexList a;
   if OBJECT_ID('tempdb..#indexList') is not null drop table #indexList;
