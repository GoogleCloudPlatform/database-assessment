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

declare @ASSESSMENT_DATABSE_NAME as VARCHAR(256);

declare @PRODUCT_VERSION as INTEGER;

declare @VALIDDB as INTEGER;

declare @DMA_SOURCE_ID as VARCHAR(256);

declare @DMA_MANUAL_ID as VARCHAR(256);

select @PKEY = N'$(pkey)';

select @CLOUDTYPE = 'NONE'
select @ASSESSMENT_DATABSE_NAME = N'$(database)';

select @PRODUCT_VERSION = convert(
      INTEGER,
      PARSENAME(
         convert(NVARCHAR, SERVERPROPERTY('productversion')),
         4
      )
   );

select @VALIDDB = 0;

select @DMA_SOURCE_ID = N'$(dmaSourceId)';

select @DMA_MANUAL_ID = N'$(dmaManualId)';

if @ASSESSMENT_DATABSE_NAME = 'all'
select @ASSESSMENT_DATABSE_NAME = '%';

if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE';

if OBJECT_ID('tempdb..#columnDatatypes') is not null drop table #COLUMNDATATYPES;
create table #COLUMNDATATYPES
(
   DATABASE_NAME NVARCHAR(255) default DB_NAME(),
   SCHEMA_NAME NVARCHAR(255),
   TABLE_NAME NVARCHAR(255),
   DATATYPE NVARCHAR(255),
   MAX_LENGTH NVARCHAR(255),
   PRECISION NVARCHAR(255),
   SCALE NVARCHAR(255),
   IS_COMPUTED NVARCHAR(10),
   IS_FILESTREAM NVARCHAR(10),
   IS_MASKED NVARCHAR(10),
   ENCRYPTION_TYPE NVARCHAR(10),
   IS_SPARSE NVARCHAR(10),
   RULE_OBJECT_ID NVARCHAR(255),
   COLUMN_COUNT NVARCHAR(255)
);

begin begin
select @VALIDDB = count(1)
from SYS.DATABASES
where NAME not in (
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
   and NAME like @ASSESSMENT_DATABSE_NAME
   and STATE = 0
end begin TRY if @PRODUCT_VERSION > 12
and @VALIDDB <> 0
and @CLOUDTYPE = 'NONE' begin exec (
   '
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

if @PRODUCT_VERSION <= 12
and @VALIDDB <> 0
and @CLOUDTYPE = 'NONE' begin exec (
   '
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

if @PRODUCT_VERSION >= 12
and @VALIDDB <> 0
and @CLOUDTYPE = 'AZURE' begin exec (
   '
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
               , c.rule_object_id'
);

end;

end TRY begin CATCH
select HOST_NAME() as HOST_NAME,
   DB_NAME() as DATABASE_NAME,
   'columnDatatypes' as MODULE_NAME,
   SUBSTRING(convert(NVARCHAR, ERROR_NUMBER()), 1, 254) as ERROR_NUMBER,
   SUBSTRING(convert(NVARCHAR, ERROR_SEVERITY()), 1, 254) as ERROR_SEVERITY,
   SUBSTRING(convert(NVARCHAR, ERROR_STATE()), 1, 254) as ERROR_STATE,
   SUBSTRING(convert(NVARCHAR, ERROR_MESSAGE()), 1, 512) as ERROR_MESSAGE;

end CATCH
end;

select @PKEY as PKEY,
   A.*,
   @DMA_SOURCE_ID as DMA_SOURCE_ID,
   @DMA_MANUAL_ID as DMA_MANUAL_ID
from #COLUMNDATATYPES A;
   if OBJECT_ID('tempdb..#columnDatatypes') is not null drop table #COLUMNDATATYPES;
