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
SELECT @PKEY = N'$(pkey)';
DECLARE @ASSESSMENT_DATABSE_NAME AS VARCHAR(256)
SELECT @ASSESSMENT_DATABSE_NAME = N'$(database)';
IF @ASSESSMENT_DATABSE_NAME = 'all'
   SELECT @ASSESSMENT_DATABSE_NAME = '%'
DECLARE @PRODUCT_VERSION AS INTEGER
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(nvarchar, SERVERPROPERTY('productversion')), 4));
DECLARE @validDB AS INTEGER
SELECT @validDB = 0
DECLARE @dbname VARCHAR(50)

DECLARE db_cursor CURSOR FOR 
SELECT name
FROM MASTER.sys.databases 
WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
AND name like @ASSESSMENT_DATABSE_NAME
AND state = 0

IF OBJECT_ID('tempdb..#connectionInfo') IS NOT NULL  
   DROP TABLE #connectionInfo;

CREATE TABLE #connectionInfo(
	database_name nvarchar(255)
    ,is_user_process nvarchar(255)
    ,host_name nvarchar(255)
    ,program_name nvarchar(255)
    ,login_name nvarchar(255)
    ,num_reads nvarchar(255)
    ,num_writes nvarchar(255)
    ,last_read nvarchar(255)
    ,last_write nvarchar(255)
    ,reads nvarchar(255)
    ,logical_reads nvarchar(255)
    ,writes nvarchar(255)
    ,client_interface_name nvarchar(255)
    ,nt_domain nvarchar(255)
    ,nt_user_name nvarchar(255)
    ,client_net_address nvarchar(255)
    ,local_net_address nvarchar(255)
    );

OPEN db_cursor  
FETCH NEXT FROM db_cursor INTO @dbname  

WHILE @@FETCH_STATUS = 0
BEGIN
    BEGIN
        SELECT @validDB = COUNT(1)
        FROM MASTER.sys.databases 
        WHERE name NOT IN ('master','model','msdb','tempdb','distribution','reportserver', 'reportservertempdb','resource','rdsadmin')
        AND name like @ASSESSMENT_DATABSE_NAME
        AND state = 0

        IF @validDB = 0
            BREAK;
    END
   
    IF @PRODUCT_VERSION >= 11
    BEGIN
        exec ('
        use [' + @dbname + '];
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
        FROM sys.dm_exec_sessions AS sdes
        INNER JOIN sys.dm_exec_connections AS sdec
                ON sdec.session_id = sdes.session_id
        WHERE sdes.session_id <> @@SPID');
    END
    IF @PRODUCT_VERSION < 11
    BEGIN
        exec ('
        use [' + @dbname + '];
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
        FROM sys.dm_exec_sessions AS sdes
        INNER JOIN sys.dm_exec_connections AS sdec
                ON sdec.session_id = sdes.session_id
        WHERE sdes.session_id <> @@SPID');
    END

    FETCH NEXT FROM db_cursor INTO @dbname 
END

CLOSE db_cursor  
DEALLOCATE db_cursor

SELECT @PKEY as PKEY, a.* from #connectionInfo a;

DROP TABLE #connectionInfo;