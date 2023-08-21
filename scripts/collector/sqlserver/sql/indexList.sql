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

SELECT @PKEY = N'$(pkey)';
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @validDB = 0
SELECT @CLOUDTYPE = 'NONE'
IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF OBJECT_ID('tempdb..#indexList') IS NOT NULL  
   DROP TABLE #objectList;

CREATE TABLE #indexList(
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
   total_space_mb nvarchar(255)
   );

BEGIN
   BEGIN
      SELECT @validDB = COUNT(1)
      FROM sys.databases 
      WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
      AND name like @ASSESSMENT_DATABSE_NAME
      AND state = 0
   END
   
   BEGIN TRY
      IF @validDB <> 0
      BEGIN
         exec ('
            INSERT INTO #indexList
            SELECT
               DB_NAME() as database_name
               ,s.name as schema_name
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
               ,p.data_compression
               ,p.data_compression_desc
               ,ISNULL (ps.name, ''Not Partitioned'') as partition_scheme
               ,ISNULL (SUM(ic.key_ordinal),0) as count_key_ordinal
               ,ISNULL (SUM(ic.partition_ordinal),0) as count_partition_ordinal
               ,ISNULL (COUNT(ic.is_included_column),0) as count_is_included_column
               ,CONVERT(nvarchar, ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2)) as total_space_mb
            FROM sys.indexes i
            JOIN sys.index_columns ic ON i.object_id = ic.object_id AND i.index_id = ic.index_id
            JOIN sys.objects o ON o.object_id = i.object_id AND o.is_ms_shipped = 0
            LEFT JOIN sys.tables t ON i.object_id = t.object_id AND t.is_ms_shipped = 0
            LEFT JOIN sys.views v ON i.object_id = v.object_id AND v.is_ms_shipped = 0
            LEFT JOIN sys.schemas s ON s.schema_id = t.schema_id
            LEFT JOIN sys.partitions AS p ON p.object_id = i.object_id AND p.index_id = i.index_id
            LEFT JOIN sys.allocation_units AS a ON a.container_id = p.partition_id
            LEFT JOIN sys.partition_schemes ps ON i.data_space_id = ps.data_space_id
            GROUP BY 
               s.name 
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
               ,p.data_compression
               ,p.data_compression_desc
               ,ISNULL (ps.name, ''Not Partitioned'')');
      END;
   END TRY
   BEGIN CATCH
      SELECT
         host_name() as host_name,
         db_name() as database_name,
         'indexList' as module_name,
         SUBSTRING(CONVERT(nvarchar,ERROR_NUMBER()),1,254) as error_number,
         SUBSTRING(CONVERT(nvarchar,ERROR_SEVERITY()),1,254) as error_severity,
         SUBSTRING(CONVERT(nvarchar,ERROR_STATE()),1,254) as error_state,
         SUBSTRING(CONVERT(nvarchar,ERROR_MESSAGE()),1,512) as error_message;
   END CATCH

END 

SELECT @PKEY as PKEY, a.*, @DMA_SOURCE_ID as dma_source_id from #indexList a;

IF OBJECT_ID('tempdb..#indexList') IS NOT NULL  
   DROP TABLE #indexList;