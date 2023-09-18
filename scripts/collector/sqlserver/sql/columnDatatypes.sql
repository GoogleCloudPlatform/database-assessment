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
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
SELECT @validDB = 0;
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

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

BEGIN
   BEGIN
      SELECT @validDB = COUNT(1)
      FROM sys.databases 
      WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
      AND name like @ASSESSMENT_DATABSE_NAME
      AND state = 0
   END
   
   BEGIN TRY
      IF @PRODUCT_VERSION > 12 AND @validDB <> 0 AND @CLOUDTYPE = 'NONE'
      BEGIN
      exec ('
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
            , c.rule_object_id');
      END;
      IF @PRODUCT_VERSION <= 12 AND @validDB <> 0 AND @CLOUDTYPE = 'NONE'
      BEGIN
      exec ('
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
            , c.rule_object_id');
      END;
      IF @PRODUCT_VERSION >= 12 AND @validDB <> 0 AND @CLOUDTYPE = 'AZURE'
      BEGIN
      exec ('
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
            , c.rule_object_id');
      END;
   END TRY
   BEGIN CATCH
      SELECT
         host_name() as host_name,
         db_name() as database_name,
         'columnDatatypes' as module_name,
         SUBSTRING(CONVERT(nvarchar,ERROR_NUMBER()),1,254) as error_number,
         SUBSTRING(CONVERT(nvarchar,ERROR_SEVERITY()),1,254) as error_severity,
         SUBSTRING(CONVERT(nvarchar,ERROR_STATE()),1,254) as error_state,
         SUBSTRING(CONVERT(nvarchar,ERROR_MESSAGE()),1,512) as error_message;
   END CATCH
   
END

SELECT 
   @PKEY as PKEY, 
   a.*, 
   @DMA_SOURCE_ID as dma_source_id,
   @DMA_MANUAL_ID as dma_manual_id
from #columnDatatypes a;

IF OBJECT_ID('tempdb..#columnDatatypes') IS NOT NULL  
   DROP TABLE #columnDatatypes;