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

DECLARE @PKEY AS VARCHAR(256);
DECLARE @CLOUDTYPE AS VARCHAR(256);
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256);
DECLARE @PRODUCT_VERSION AS INTEGER;
DECLARE @VALIDDB AS INTEGER;
DECLARE @DMA_SOURCE_ID AS VARCHAR(256);
DECLARE @DMA_MANUAL_ID AS VARCHAR(256);

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE'
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR, SERVERPROPERTY('productversion')), 4));
SELECT @VALIDDB = 0;
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF @ASSESSMENT_DATABSE_NAME = 'all'
SELECT @ASSESSMENT_DATABSE_NAME = '%';

IF UPPER(@@VERSION) LIKE '%AZURE%'
   SELECT @CLOUDTYPE = 'AZURE';

BEGIN
   BEGIN
      SELECT
         @VALIDDB = COUNT(1)
      FROM
         SYS.DATABASES
      WHERE
         NAME NOT IN ('master', 'model', 'msdb', 'tempdb', 'distribution', 'reportserver', 'reportservertempdb', 'resource', 'rdsadmin')
         AND NAME LIKE @ASSESSMENT_DATABSE_NAME
         AND STATE = 0
   END

   BEGIN TRY 
   IF @PRODUCT_VERSION > 12 AND @VALIDDB <> 0 AND @CLOUDTYPE = 'NONE'    
      BEGIN
      EXEC ('
         SELECT 
               ''' + @PKEY + ''' AS pkey
               , s.name AS schema_name
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
               , ''' + @DMA_SOURCE_ID + ''' as dma_source_id
               , ''' + @DMA_MANUAL_ID + ''' as dma_manual_id
            FROM  sys.objects o 
            JOIN  sys.schemas s
               ON  s.schema_id = o.schema_id
            JOIN  sys.columns c
            ON  o.object_id = c.object_id
            JOIN  sys.types t
            ON  t.system_type_id = c.system_type_id AND t.user_type_id = c.user_type_id
         WHERE o.type_desc = ''USER_TABLE'' 
            -- AND t.system_type_id = t.user_type_id /* Removing to capture datatypes like hierarchyid */
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

   IF @PRODUCT_VERSION <= 12 AND @VALIDDB <> 0 AND @CLOUDTYPE = 'NONE'
      BEGIN
      EXEC ('
         SELECT 
               ''' + @PKEY + ''' AS pkey
               , s.name AS schema_name
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
               , ''' + @DMA_SOURCE_ID + ''' as dma_source_id
               , ''' + @DMA_MANUAL_ID + ''' as dma_manual_id
            FROM  sys.objects o 
            JOIN  sys.schemas s
               ON  s.schema_id = o.schema_id
            JOIN  sys.columns c
            ON  o.object_id = c.object_id
            JOIN  sys.types t
            ON  t.system_type_id = c.system_type_id AND t.user_type_id = c.user_type_id
         WHERE o.type_desc = ''USER_TABLE'' 
            -- AND t.system_type_id = t.user_type_id /* Removing to capture datatypes like hierarchyid */
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

   IF @PRODUCT_VERSION >= 12 AND @VALIDDB <> 0 AND @CLOUDTYPE = 'AZURE'
      BEGIN
      EXEC ('
         SELECT
               ''' + @PKEY + ''' AS pkey
               , s.name AS schema_name
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
               , ''' + @DMA_SOURCE_ID + ''' as dma_source_id
               , ''' + @DMA_MANUAL_ID + ''' as dma_manual_id
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
      HOST_NAME() AS HOST_NAME,
      DB_NAME() AS DATABASE_NAME,
      'columnDatatypes' AS MODULE_NAME,
      SUBSTRING(CONVERT(NVARCHAR, ERROR_NUMBER()), 1, 254) AS ERROR_NUMBER,
      SUBSTRING(CONVERT(NVARCHAR, ERROR_SEVERITY()), 1, 254) AS ERROR_SEVERITY,
      SUBSTRING(CONVERT(NVARCHAR, ERROR_STATE()), 1, 254) AS ERROR_STATE,
      SUBSTRING(CONVERT(NVARCHAR, ERROR_MESSAGE()), 1, 512) AS ERROR_MESSAGE;
END CATCH
END;