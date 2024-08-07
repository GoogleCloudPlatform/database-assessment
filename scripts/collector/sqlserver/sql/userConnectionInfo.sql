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
    END;
    BEGIN TRY
        IF @PRODUCT_VERSION >= 11 AND @validDB <> 0
        BEGIN
            exec ('
                SELECT
                    ''"' + @PKEY + '"'' AS pkey
                    , ''"'' + CONVERT(NVARCHAR(255), DB_NAME()) + ''"'' as database_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.is_user_process) + ''"'' as is_user_process
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.host_name) + ''"'' as host_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.program_name) + ''"'' as program_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.login_name) + ''"'' as login_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.num_reads) + ''"'' as num_reads
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.num_writes) + ''"'' as num_writes
                    , ''"'' + CONVERT(NVARCHAR(255), FORMAT(sdec.last_read,''yyyy-MM-dd HH:mm:ss'')) + ''"'' as last_read
                    , ''"'' + CONVERT(NVARCHAR(255), FORMAT(sdec.last_write,''yyyy-MM-dd HH:mm:ss'')) + ''"'' as last_write
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.reads) + ''"'' as reads
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.logical_reads) + ''"'' as logical_reads
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.writes) + ''"'' as writes
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.client_interface_name) + ''"'' as client_interface_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.nt_domain) + ''"'' as nt_domain
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.nt_user_name) + ''"'' as nt_user_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.client_net_address) + ''"'' as client_net_address
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.local_net_address) + ''"'' as local_net_address
                    , ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id
        		    , ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.client_version) + ''"'' as client_version
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.protocol_type) + ''"'' as protocol_type
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.protocol_version) + ''"'' as protocol_version
                    , ''"'' + CONVERT(NVARCHAR(255), sys.fn_varbintohexstr(sdec.protocol_version)) + ''"'' as protocol_hex_version
                FROM sys.dm_exec_sessions AS sdes
                INNER JOIN sys.dm_exec_connections AS sdec
                        ON sdec.session_id = sdes.session_id
                WHERE sdes.session_id <> @@SPID
            ');
        END;
        IF @PRODUCT_VERSION < 11 AND @validDB <> 0
        BEGIN
            exec ('
                SELECT
                    ''"' + @PKEY + '"'' AS pkey
                    , ''"'' + CONVERT(NVARCHAR(255), DB_NAME()) + ''"'' as database_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.is_user_process) + ''"'' as is_user_process
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.host_name) + ''"'' as host_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.program_name) + ''"'' as program_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.login_name) + ''"'' as login_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.num_reads) + ''"'' as num_reads
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.num_writes) + ''"'' as num_writes
                    , ''"'' + CONVERT(VARCHAR(256), sdec.last_read, 120) + ''"'' as last_read
                    , ''"'' + CONVERT(VARCHAR(256), sdec.last_write,120) + ''"'' as last_write
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.reads) + ''"'' as reads
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.logical_reads) + ''"'' as logical_reads
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.writes) + ''"'' as writes
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.client_interface_name) + ''"'' as client_interface_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.nt_domain) + ''"'' as nt_domain
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.nt_user_name) + ''"'' as nt_user_name
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.client_net_address) + ''"'' as client_net_address
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.local_net_address) + ''"'' as local_net_address
                    , ''"' + @DMA_SOURCE_ID + '"'' as dma_source_id
        		    , ''"' + @DMA_MANUAL_ID + '"'' as dma_manual_id
                    , ''"'' + CONVERT(NVARCHAR(255), sdes.client_version) + ''"'' as client_version
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.protocol_type) + ''"'' as protocol_type
                    , ''"'' + CONVERT(NVARCHAR(255), sdec.protocol_version) + ''"'' as protocol_version
                    , ''"'' + CONVERT(NVARCHAR(255), sys.fn_varbintohexstr(sdec.protocol_version)) + ''"'' as protocol_hex_version
                FROM sys.dm_exec_sessions AS sdes
                INNER JOIN sys.dm_exec_connections AS sdec
                        ON sdec.session_id = sdes.session_id
                WHERE sdes.session_id <> @@SPID
            ');
        END;
    END TRY
    BEGIN CATCH
        SELECT
        host_name() as host_name,
        db_name() as database_name,
        'connectionInfo' as module_name,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_NUMBER()),1,254) as error_number,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_SEVERITY()),1,254) as error_severity,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_STATE()),1,254) as error_state,
        SUBSTRING(CONVERT(NVARCHAR(255),ERROR_MESSAGE()),1,512) as error_message;
    END CATCH
END;
