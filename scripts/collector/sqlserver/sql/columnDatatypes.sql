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


BEGIN
   BEGIN
      SELECT
         @VALIDDB = count(1)
      FROM
         sys.databases
      WHERE
         name NOT IN ('master', 'model', 'msdb', 'tempdb', 'distribution', 'reportserver', 'reportservertempdb', 'resource', 'rdsadmin')
         AND name LIKE @ASSESSMENT_DATABSE_NAME
         AND state = 0
   END

   BEGIN TRY 
   IF @PRODUCT_VERSION > 12 AND @VALIDDB <> 0 AND @CLOUDTYPE = 'NONE'    
      BEGIN
      EXEC ('
         SELECT 
               ''"' + @PKEY + '"'' AS pkey
               , QUOTENAME(db_name(),''"'') as database_name
               , QUOTENAME(s.name,''"'')  AS schema_name
               , QUOTENAME(o.name,''"'')  AS table_name
               , QUOTENAME(t.name,''"'')  AS datatype
               , QUOTENAME(c.max_length,''"'') AS max_length
               , QUOTENAME(c.precision,''"'') AS precision
               , QUOTENAME(c.scale,''"'') AS scale
               , QUOTENAME(c.is_computed,''"'') AS is_computed
               , QUOTENAME(c.is_filestream,''"'') AS is_filestream
               , QUOTENAME(c.is_masked,''"'') AS is_masked
               , QUOTENAME(ISNULL(c.encryption_type,0),''"'')  AS encryption_type
               , QUOTENAME(c.is_sparse,''"'') AS is_sparse
               , QUOTENAME(c.rule_object_id,''"'') AS rule_object_id
               , QUOTENAME(count(1),''"'') AS column_count
               , ''"' + @DMA_SOURCE_ID + '"'' AS dma_source_id
               , ''"' + @DMA_MANUAL_ID + '"'' AS dma_manual_id
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
               , c.rule_object_id'
);

end;


   IF @PRODUCT_VERSION <= 12 AND @VALIDDB <> 0 AND @CLOUDTYPE = 'NONE'
      BEGIN
      EXEC ('
         SELECT 
               ''"' + @PKEY + '"'' AS pkey
               , QUOTENAME(db_name(),''"'') AS database_name
               , QUOTENAME(s.name,''"'')  AS schema_name
               , QUOTENAME(o.name,''"'')  AS table_name
               , QUOTENAME(t.name,''"'')  AS datatype
               , QUOTENAME(c.max_length,''"'') AS max_length
               , QUOTENAME(c.precision,''"'') AS precision
               , QUOTENAME(c.scale,''"'') AS scale
               , QUOTENAME(c.is_computed,''"'') AS is_computed
               , QUOTENAME(c.is_filestream,''"'') AS is_filestream
               , QUOTENAME(0 as is_masked,''"'') AS is_masked
               , QUOTENAME(0 AS encryption_type,''"'') AS encryption_type
               , QUOTENAME(c.is_sparse,''"'') AS is_sparse
               , QUOTENAME(c.rule_object_id,''"'') AS rule_object_id
               , QUOTENAME(count(1),''"'') AS column_count
               , ''"' + @DMA_SOURCE_ID + '"'' AS dma_source_id
               , ''"' + @DMA_MANUAL_ID + '"'' AS dma_manual_id
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
               , c.rule_object_id'
);

end;


   IF @PRODUCT_VERSION >= 12 AND @VALIDDB <> 0 AND @CLOUDTYPE = 'AZURE'
      BEGIN
      EXEC ('
         SELECT
               ''"' + @PKEY + '"'' AS pkey
               , QUOTENAME(db_name(),''"'') AS database_name
               , QUOTENAME(s.name,''"'') AS schema_name
               , QUOTENAME(o.name,''"'')  AS table_name
               , QUOTENAME(t.name,''"'')  AS datatype
               , QUOTENAME(c.max_length,''"'') AS max_length
               , QUOTENAME(c.precision,''"'') AS precision
               , QUOTENAME(c.scale,''"'') AS scale
               , QUOTENAME(c.is_computed,''"'') AS is_computed
               , QUOTENAME(c.is_filestream,''"'') AS is_filestream
               , QUOTENAME(c.is_masked,''"'') AS is_masked
               , QUOTENAME(ISNULL(c.encryption_type,0),''"'') AS encryption_type
               , QUOTENAME(c.is_sparse,''"'') AS is_sparse
               , QUOTENAME(c.rule_object_id,''"'') AS rule_object_id
               , QUOTENAME(count(1),''"'') AS column_count
               , ''"' + @DMA_SOURCE_ID + '"'' AS dma_source_id
               , ''"' + @DMA_MANUAL_ID + '"'' AS dma_manual_id
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
