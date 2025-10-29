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
DECLARE @CLOUDTYPE AS VARCHAR(256)
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @validDB AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE'
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @validDB = 0;
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

BEGIN
   BEGIN
      SELECT @validDB = COUNT(1)
      FROM sys.databases
      WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
         AND name like @ASSESSMENT_DATABSE_NAME
         AND state = 0
         AND is_read_only = 0
   END

   BEGIN TRY
      IF @validDB <> 0
      BEGIN
      exec ('
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
            SELECT
               ''"' + @PKEY + '"'' AS pkey,
               ''"'' + CONVERT(NVARCHAR(MAX), DB_NAME()) + ''"'' as database_name,
               CASE
	               WHEN s.name IS NULL
                     THEN ''"'' + CONVERT(NVARCHAR(MAX), v.schema_name) + ''"''
		            ELSE ''"'' + CONVERT(NVARCHAR(MAX), s.name) + ''"''
	            END as schema_name,
               CASE
                  WHEN t.name IS NULL
                     THEN ''"'' + CONVERT(NVARCHAR(MAX), v.name) + ''"''
                  ELSE ''"'' + CONVERT(NVARCHAR(MAX), t.name) + ''"''
               END as table_name,
               ''"'' + CONVERT(NVARCHAR(MAX), i.name) + ''"'' as index_name,
               ''"'' + CONVERT(NVARCHAR(MAX), i.type_desc) + ''"'' as index_type,
               ''"'' + CONVERT(NVARCHAR(MAX), i.is_primary_key) + ''"'' as is_primary_key,
               ''"'' + CONVERT(NVARCHAR(MAX), i.is_unique) + ''"'' as is_unique,
               ''"'' + CONVERT(NVARCHAR(MAX), i.fill_factor) + ''"'' as fille_factor,
               ''"'' + CONVERT(NVARCHAR(MAX), i.allow_page_locks) + ''"'' as allow_page_locks,
               ''"'' + CONVERT(NVARCHAR(MAX), i.has_filter) + ''"'' as has_filter,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(p.data_compression,0)) + ''"'' as data_compression,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(p.data_compression_desc,''NONE'')) + ''"'' as data_compression_desc,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(ps.name, ''Not Partitioned'')) + ''"'' as partition_scheme,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(SUM(ic.key_ordinal),0)) + ''"'' as count_key_ordinal,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(SUM(ic.partition_ordinal),0)) + ''"'' as count_partition_ordinal,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(SUM(CONVERT(int,ic.is_included_column)),0)) + ''"'' as count_is_included_column,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(CONVERT(NVARCHAR(255), ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2)),0)) + ''"'' as total_space_mb,
               ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
               ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL(icc.is_computed_index,0)) + ''"'' as is_computed_index,
               CASE
                  WHEN v.name IS NOT NULL
                     THEN ''"1"''
                  ELSE ''"0"''
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
	               WHEN s.name IS NULL
                     THEN ''"'' + CONVERT(NVARCHAR(MAX), v.schema_name) + ''"''
		            ELSE ''"'' + CONVERT(NVARCHAR(MAX), s.name) + ''"''
	            END
               ,CASE
                  WHEN t.name IS NULL
                     THEN ''"'' + CONVERT(NVARCHAR(MAX), v.name) + ''"''
                  ELSE ''"'' + CONVERT(NVARCHAR(MAX), t.name) + ''"''
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
                  WHEN v.name IS NOT NULL
                     THEN ''"1"''
                  ELSE ''"0"''
               END
            UNION
            SELECT
               ''"' + @PKEY + '"'' AS pkey,
               ''"'' + CONVERT(NVARCHAR(MAX), DB_NAME()) + ''"'' as database_name,
               ''"'' + CONVERT(NVARCHAR(MAX), s.name) + ''"'' as schema_name,
               ''"'' + CONVERT(NVARCHAR(MAX), t.name) + ''"'' as table_name,
               ''"'' + CONVERT(NVARCHAR(MAX), o.name) + ''"'' as index_name,
               ''"FULLTEXT"'' as index_type,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as is_primary_key,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as is_unique,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as fill_factor,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as allow_page_locks,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as has_filter,
               ''"'' + CONVERT(NVARCHAR(MAX), p.data_compression) + ''"'' as data_compression,
               ''"'' + CONVERT(NVARCHAR(MAX), p.data_compression_desc) + ''"'' as data_compression_desc,
               ''"'' + CONVERT(NVARCHAR(MAX), ISNULL (ps.name, ''Not Partitioned'')) + ''"'' as partition_scheme,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as count_key_ordinal,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as count_partition_ordinal,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as count_is_included_column,
               ''"'' + CONVERT(NVARCHAR(MAX), CONVERT(NVARCHAR(255), ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2))) + ''"'' as total_space_mb,
               ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id,
               ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as is_computed_index,
               ''"'' + CONVERT(NVARCHAR(MAX), 0) + ''"'' as is_index_on_view
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
               ISNULL (ps.name, ''Not Partitioned'')');
   END;
   END TRY
   BEGIN CATCH
      SELECT
      host_name() as host_name,
      db_name() as database_name,
      'indexList' as module_name,
      SUBSTRING(CONVERT(NVARCHAR(255),ERROR_NUMBER()),1,254) as error_number,
      SUBSTRING(CONVERT(NVARCHAR(255),ERROR_SEVERITY()),1,254) as error_severity,
      SUBSTRING(CONVERT(NVARCHAR(255),ERROR_STATE()),1,254) as error_state,
      SUBSTRING(CONVERT(NVARCHAR(255),ERROR_MESSAGE()),1,512) as error_message;
   END CATCH
END;
