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
select @CLOUDTYPE = 'AZURE' if OBJECT_ID('tempdb..#connectionInfo') is not null drop table #connectionInfo;
    create table #connectionInfo
    (
        database_name nvarchar(255),
        is_user_process nvarchar(255),
        host_name nvarchar(255),
        program_name nvarchar(255),
        login_name nvarchar(255),
        num_reads nvarchar(255),
        num_writes nvarchar(255),
        last_read nvarchar(255),
        last_write nvarchar(255),
        reads nvarchar(255),
        logical_reads nvarchar(255),
        writes nvarchar(255),
        client_interface_name nvarchar(255),
        nt_domain nvarchar(255),
        nt_user_name nvarchar(255),
        client_net_address nvarchar(255),
        local_net_address nvarchar(255),
        client_version nvarchar(255),
        protocol_type nvarchar(255),
        protocol_version nvarchar(255),
        protocol_hex_version nvarchar(255)
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
end begin TRY if @PRODUCT_VERSION >= 11
and @validDB <> 0 begin exec (
    '
            INSERT INTO #connectionInfo
            SELECT
                DB_NAME() as database_name
                ,sdes.is_user_process
                ,sdes.host_name
                ,sdes.program_name
                ,sdes.login_name
                ,sdec.num_reads
                ,sdec.num_writes
                ,FORMAT(sdec.last_read,''yyyy-MM-dd HH:mm:ss'') as last_read
                ,FORMAT(sdec.last_write,''yyyy-MM-dd HH:mm:ss'') as last_write
                ,sdes.reads
                ,sdes.logical_reads
                ,sdes.writes
                ,sdes.client_interface_name
                ,sdes.nt_domain
                ,sdes.nt_user_name
                ,sdec.client_net_address
                ,sdec.local_net_address
                ,sdes.client_version
                ,sdec.protocol_type
                ,sdec.protocol_version
                ,sys.fn_varbintohexstr(sdec.protocol_version) as protocol_hex_version
            FROM sys.dm_exec_sessions AS sdes
            INNER JOIN sys.dm_exec_connections AS sdec
                    ON sdec.session_id = sdes.session_id
            WHERE sdes.session_id <> @@SPID'
);

end if @PRODUCT_VERSION < 11
and @validDB <> 0 begin exec (
    '
            INSERT INTO #connectionInfo
            SELECT
                DB_NAME() as database_name
                ,sdes.is_user_process
                ,sdes.host_name
                ,sdes.program_name
                ,sdes.login_name
                ,sdec.num_reads
                ,sdec.num_writes
                ,CONVERT(VARCHAR(256),sdec.last_read, 120) as last_read
                ,CONVERT(VARCHAR(256),sdec.last_write,120) as last_write
                ,sdes.reads
                ,sdes.logical_reads
                ,sdes.writes
                ,sdes.client_interface_name
                ,sdes.nt_domain
                ,sdes.nt_user_name
                ,sdec.client_net_address
                ,sdec.local_net_address
                ,sdes.client_version
                ,sdec.protocol_type
                ,sdec.protocol_version
                ,sys.fn_varbintohexstr(sdec.protocol_version) as protocol_hex_version
            FROM sys.dm_exec_sessions AS sdes
            INNER JOIN sys.dm_exec_connections AS sdec
                    ON sdec.session_id = sdes.session_id
            WHERE sdes.session_id <> @@SPID'
);

end
end TRY begin CATCH
select host_name() as host_name,
    db_name() as database_name,
    'connectionInfo' as module_name,
    SUBSTRING(convert(nvarchar, ERROR_NUMBER()), 1, 254) as error_number,
    SUBSTRING(convert(nvarchar, ERROR_SEVERITY()), 1, 254) as error_severity,
    SUBSTRING(convert(nvarchar, ERROR_STATE()), 1, 254) as error_state,
    SUBSTRING(convert(nvarchar, ERROR_MESSAGE()), 1, 512) as error_message;

end CATCH
end
select @PKEY as PKEY,
    database_name,
    is_user_process,
    host_name,
    program_name,
    login_name,
    num_reads,
    num_writes,
    last_read,
    last_write,
    reads,
    logical_reads,
    writes,
    client_interface_name,
    nt_domain,
    nt_user_name,
    client_net_address,
    local_net_address,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id,
    client_version,
    protocol_type,
    protocol_version,
    protocol_hex_version
from #connectionInfo a;
    if OBJECT_ID('tempdb..#connectionInfo') is not null drop table #connectionInfo;
