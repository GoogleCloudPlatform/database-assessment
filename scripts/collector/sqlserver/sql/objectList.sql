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

select @validDB = 0
select @DMA_SOURCE_ID = N'$(dmaSourceId)';

select @DMA_MANUAL_ID = N'$(dmaManualId)';

if @ASSESSMENT_DATABASE_NAME = 'all'
select @ASSESSMENT_DATABASE_NAME = '%' if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE' if OBJECT_ID('tempdb..#objectList') is not null drop table #objectList;
    create table #objectList
    (
        database_name nvarchar(255),
        schema_name nvarchar(255),
        object_name nvarchar(255),
        object_type nvarchar(255),
        object_type_desc nvarchar(255),
        object_count nvarchar(255),
        lines_of_code nvarchar(255),
        associated_table_name nvarchar(255)
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
        INSERT INTO #objectList
        SELECT 
            database_name,
            schema_name,
            NameOfObject as object_name,
            RTRIM(LTRIM(type)) as type,
            type_desc,
            count(*) AS object_count,
            ISNULL(SUM(LinesOfCode),0) AS lines_of_code,
            associated_table_name
        FROM (
            SELECT
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(o.type)) as type, 
                o.type_desc, 
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode, 
                OBJECT_NAME(o.object_id) AS NameOfObject ,
                NULL as associated_table_name
            FROM 
                sys.objects o
                JOIN sys.schemas s ON (s.schema_id = o.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = o.object_id)
            WHERE 
                o.type NOT IN (
                    ''S'' --SYSTEM_TABLE
                    , 
                    ''IT'' --INTERNAL_TABLE
                    ,
                    ''F'' --FOREIGN KEY
                    ,
                    ''PK''  --PRIMARY KEY
                    ,
                    ''C''  -- CHECK CONSTRAINT
                    ,
                    ''D''  --DEFAULT CONSTRAINT
                    ,
                    ''UQ''  --UNIQUE CONSTRAINT
                    ,
                    ''TR'' --TRIGGER
                    ,
                    ''V'' --VIEW
                    ) 
                AND OBJECTPROPERTY(o.object_id, ''IsMSShipped'') = 0
            UNION
            SELECT
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(type)) as type,
                type_desc,
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode,
                cc.name AS NameOfObject,
                object_name(cc.parent_object_id) AS associated_table_name
            FROM 
                sys.check_constraints cc
                JOIN sys.schemas s ON (s.schema_id = cc.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = cc.object_id)
            WHERE cc.is_ms_shipped = 0
            UNION
            SELECT 
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(type)) as type,
                type_desc,
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode,
                fk.name AS NameOfObject ,
                object_name(fk.parent_object_id) AS associated_table_name
            FROM 
                sys.foreign_keys fk
                JOIN sys.schemas s ON (s.schema_id = fk.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = fk.object_id)
            WHERE fk.is_ms_shipped = 0
            UNION
            SELECT 
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(type)) as type,
                type_desc,
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode,
                dc.name AS NameOfObject ,
                object_name(dc.parent_object_id) AS associated_table_name
            FROM 
                sys.default_constraints dc
                JOIN sys.schemas s ON (s.schema_id = dc.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = dc.object_id)
            WHERE dc.is_ms_shipped = 0
            UNION
            SELECT
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(type)) as type,
                type_desc,
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode,
                kc.name AS NameOfObject,
                object_name(kc.parent_object_id) AS associated_table_name
            FROM
                sys.key_constraints kc
                JOIN sys.schemas s ON (s.schema_id = kc.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = kc.object_id)
            WHERE kc.is_ms_shipped = 0
            UNION
            SELECT 
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(t.type)) as type,
                t.type_desc,
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode,
                t.name AS NameOfObject ,
                object_name(t.parent_id) AS associated_table_name
            FROM 
                sys.triggers t
                JOIN sys.tables tbl ON (tbl.object_id = t.parent_id)
                LEFT OUTER JOIN sys.schemas s ON (s.schema_id = tbl.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = t.object_id)
            WHERE t.is_ms_shipped = 0
            UNION
            SELECT 
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                RTRIM(LTRIM(type)) as type,
                type_desc,
                ISNULL(LEN(a.definition)- LEN(REPLACE(a.definition, CHAR(10), '''')),0) AS LinesOfCode,
                v.name AS NameOfObject ,
                NULL as associated_table_name
            FROM
                sys.views v
                JOIN sys.schemas s ON (s.schema_id = v.schema_id)
                LEFT OUTER JOIN sys.all_sql_modules a ON (a.OBJECT_ID = v.object_id)
            WHERE v.is_ms_shipped = 0
            UNION
            SELECT 
                DB_NAME(DB_ID()) as database_name,
                s.name as schema_name,
                ''TT'' as type,
                ''TABLE_TYPES'',
                0 AS LinesOfCode,
                t.name AS NameOfObject ,
                NULL as associated_table_name
            FROM
                sys.types t
                JOIN sys.schemas s ON (s.schema_id = t.schema_id)
            WHERE t.system_type_id <> t.user_type_id and t.is_user_defined = 1 and t.is_table_type = 1
        ) SubQuery 
        GROUP BY 
            database_name,
            schema_name,
            NameOfObject,
            type, 
            type_desc,
            associated_table_name'
);

end;

end TRY begin CATCH
select host_name() as host_name,
    db_name() as database_name,
    'objectList' as module_name,
    SUBSTRING(convert(nvarchar, ERROR_NUMBER()), 1, 254) as error_number,
    SUBSTRING(convert(nvarchar, ERROR_SEVERITY()), 1, 254) as error_severity,
    SUBSTRING(convert(nvarchar, ERROR_STATE()), 1, 254) as error_state,
    SUBSTRING(convert(nvarchar, ERROR_MESSAGE()), 1, 512) as error_message;

end CATCH
end
select @PKEY as PKEY,
    a.*,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from #objectList a;
    if OBJECT_ID('tempdb..#objectList') is not null drop table #objectList;
