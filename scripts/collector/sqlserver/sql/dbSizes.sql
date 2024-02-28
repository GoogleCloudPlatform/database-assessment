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

select @CLOUDTYPE = 'NONE';

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
end begin TRY if @validDB <> 0 begin
select @PKEY as PKEY,
    sizing.*,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id
from(
        select db_name() as database_name,
            type_desc,
            SUM(size / 128.0) as current_size_mb
        from sys.database_files sm
        where db_name() not in (
                'master',
                'model',
                'msdb',
                'distribution',
                'reportserver',
                'reportservertempdb',
                'resource',
                'rdsadmin'
            )
            and type in (0, 1)
            and exists (
                select 1
                from sys.databases sd
                where state = 0
                    and sd.name not in (
                        'master',
                        'model',
                        'msdb',
                        'distribution',
                        'reportserver',
                        'reportservertempdb',
                        'resource',
                        'rdsadmin'
                    )
                    and sd.name like @ASSESSMENT_DATABASE_NAME
                    and sd.state = 0
                    and sd.name = db_name()
            )
        group by type_desc
    ) sizing
end
end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 WAITFOR DELAY '00:00:00'
else
select host_name() as host_name,
    db_name() as database_name,
    'columnDatatypes' as module_name,
    SUBSTRING(convert(nvarchar, ERROR_NUMBER()), 1, 254) as error_number,
    SUBSTRING(convert(nvarchar, ERROR_SEVERITY()), 1, 254) as error_severity,
    SUBSTRING(convert(nvarchar, ERROR_STATE()), 1, 254) as error_state,
    SUBSTRING(convert(nvarchar, ERROR_MESSAGE()), 1, 512) as error_message
end CATCH
end
