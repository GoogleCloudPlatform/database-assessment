/*
 Copyright 2024 Google LLC

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
declare @PRODUCT_VERSION as INTEGER
declare @TABLE_PERMISSION_COUNT as INTEGER
declare @ROW_COUNT_VAR as INTEGER
declare @DMA_SOURCE_ID as VARCHAR(256)
declare @DMA_MANUAL_ID as VARCHAR(256)
select @PKEY = N'$(pkey)';

select @CLOUDTYPE = 'NONE';

select @PRODUCT_VERSION = convert(
        INTEGER,
        PARSENAME(
            convert(nvarchar, SERVERPROPERTY('productversion')),
            4
        )
    );

select @DMA_SOURCE_ID = N'$(dmaSourceId)';

select @DMA_MANUAL_ID = N'$(dmaManualId)';

if UPPER(@@VERSION) like '%AZURE%'
select @CLOUDTYPE = 'AZURE' if OBJECT_ID('tempdb..#FeaturesEnabled') is not null drop table #FeaturesEnabled;
    create table #FeaturesEnabled
    (
        Features NVARCHAR(40),
        Is_EnabledOrUsed NVARCHAR(4),
        count INT
    );

if OBJECT_ID('tempdb..#myPerms') is not null drop table #myPerms;
create table #myPerms
(
    entity_name nvarchar(255),
    subentity_name nvarchar(255),
    permission_name nvarchar(255)
);

insert into #myPerms
select *
from fn_my_permissions('msdb.dbo.sysmail_server', 'OBJECT')
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions('msdb.dbo.sysmail_profile', 'OBJECT')
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions('msdb.dbo.sysmail_profileaccount', 'OBJECT')
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions('msdb.dbo.sysmail_account', 'OBJECT')
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions(
        'msdb.dbo.log_shipping_secondary_databases',
        'OBJECT'
    )
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions(
        'msdb.dbo.log_shipping_primary_databases',
        'OBJECT'
    )
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions('msdb.dbo.sysmaintplan_subplans', 'OBJECT')
where permission_name = 'SELECT'
    and subentity_name = '';

insert into #myPerms
select *
from fn_my_permissions('msdb.dbo.sysjobs', 'OBJECT')
where permission_name = 'SELECT'
    and subentity_name = '';

--DB Mail
select @TABLE_PERMISSION_COUNT = count(*)
from #myPerms
where LOWER(entity_name) in (
        'dbo.sysmail_profile',
        'dbo.sysmail_profileaccount',
        'dbo.sysmail_account',
        'dbo.sysmail_server'
    )
    and UPPER(permission_name) = 'SELECT';

if @TABLE_PERMISSION_COUNT >= 4
and @CLOUDTYPE = 'NONE' begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsDbMailEnabled'',
        CONVERT(nvarchar, value_in_use),
        CASE WHEN value_in_use > 0 THEN 1
        ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''Database Mail XPs'''
);

end
else begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsDbMailEnabled'',
        ''0'',
        0
    FROM sys.configurations
    WHERE name = ''Database Mail XPs'''
);

end;

--external scripts enabled
begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsExternalScriptsEnabled'',
        CONVERT(nvarchar, value_in_use),
        CASE WHEN value_in_use > 0 THEN 1
        ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''external scripts enabled'''
);


-- Data Quality Services
BEGIN
    BEGIN TRY
        exec('
        WITH dqs_service as (
        select count(*) as dqs_count from syslogins where name like ''##MS_dqs%'')
        INSERT INTO #FeaturesEnabled 
            SELECT 
                ''DATA QUALITY SERVICES'' as Features,
                CASE 
                    WHEN dqs_count > 0 THEN 1
                    ELSE 0
                END AS Is_EnabledOrUsed,
                dqs_count as Count
            from dqs_service');
        END TRY
    BEGIN CATCH
        exec('
        WITH dqs_service as (
        select count(*) as dqs_count from sys.sql_logins where name like ''##MS_dqs%'')
        INSERT INTO #FeaturesEnabled 
            SELECT 
                ''DATA QUALITY SERVICES'' as Features,
                CASE 
                    WHEN dqs_count > 0 THEN 1
                    ELSE 0
                END AS Is_EnabledOrUsed,
                dqs_count as Count
            from dqs_service');
        END CATCH
END;

--filestream enabled
IF @PRODUCT_VERSION >= 11
BEGIN
    BEGIN TRY
        exec('WITH check_filestream AS (
            SELECT
                name,
                ISNULL((SELECT count(1) FROM sys.master_files AS mf WHERE mf.database_id = db.database_id AND mf.type = 2),0) AS hasfs
            FROM sys.databases AS db
        )
        INSERT INTO #FeaturesEnabled SELECT
            ''IsFileStreamEnabled'',
            CASE WHEN sum(hasfs) > 0 THEN ''1''
            ELSE ''0''
            END,
            CASE WHEN sum(hasfs) > 0 THEN 1
            ELSE 0
            END
        FROM
            check_filestream
        /* SQL Server 2012 (11.x) above */'
);

end TRY begin CATCH exec(
    '
        INSERT INTO #FeaturesEnabled VALUES (
            ''IsFileStreamEnabled'',
            ''0'',
            0)
        '
);

end CATCH
end
else begin exec(
    '
    INSERT INTO #FeaturesEnabled VALUES (
        ''IsFileStreamEnabled'',
        ''0'',
        0)
    '
);

end --hybrid buffer pool enabled
if @CLOUDTYPE = 'AZURE' begin exec(
    'INSERT INTO #FeaturesEnabled
            SELECT ''IsHybridBufferPoolEnabled'',
            CONVERT(nvarchar,is_enabled),
            CASE
                WHEN is_configured > 0 THEN 1
                ELSE 0
            END
            from sys.server_memory_optimized_hybrid_buffer_pool_configuration
            /* SQL Server 2019 (15.x) and later versions */'
);

end
else begin if @PRODUCT_VERSION >= 15 begin
select @ROW_COUNT_VAR = count(*)
from sys.server_memory_optimized_hybrid_buffer_pool_configuration;

if @ROW_COUNT_VAR = 0 begin exec(
    'INSERT INTO #FeaturesEnabled
                    SELECT
                        ''IsHybridBufferPoolEnabled'',
                        ''0'',
                        0'
);

end;

if @ROW_COUNT_VAR > 0 begin exec(
    'INSERT INTO #FeaturesEnabled
                SELECT ''IsHybridBufferPoolEnabled'',
                COALESCE(CONVERT(nvarchar,is_enabled), 0),
                CASE
                    WHEN is_enabled > 0 THEN 1
                ELSE 0
                END
                from sys.server_memory_optimized_hybrid_buffer_pool_configuration
                /* SQL Server 2019 (15.x) and later versions */'
);

end;

end;

else begin exec(
    'INSERT INTO #FeaturesEnabled
            SELECT
            ''IsHybridBufferPoolEnabled'',
            ''0'',
            0
            /* Earlier than SQL Server 2019 (15.x) versions */'
);

end;

end;

--log shipping enabled
select @TABLE_PERMISSION_COUNT = count(*)
from #myPerms
where LOWER(entity_name) in (
        'dbo.log_shipping_primary_databases',
        'dbo.log_shipping_secondary_databases'
    )
    and UPPER(permission_name) = 'SELECT';

if @TABLE_PERMISSION_COUNT >= 2
and @CLOUDTYPE = 'NONE' begin exec(
    'WITH log_shipping_count AS (
        SELECT
            count(*) log_shipping
        FROM
            msdb..log_shipping_primary_databases
        UNION ALL
        SELECT
            count(*) log_shipping
        FROM
            msdb..log_shipping_secondary_databases
    )
    INSERT INTO #FeaturesEnabled
		SELECT
        ''IsLogShippingEnabled'',
        COALESCE(CONVERT(varchar,sum(log_shipping)),''0''),
        COALESCE(sum(log_shipping),0))
    FROM
        log_shipping_count'
);

end;

else begin exec(
    'INSERT INTO #FeaturesEnabled VALUES (''IsLogShippingEnabled'', ''0'', 0)'
);

end;

--maintenance plans enabled
select @TABLE_PERMISSION_COUNT = count(*)
from #myPerms
where LOWER(entity_name) in ('dbo.sysmaintplan_subplans', 'dbo.sysjobs')
    and UPPER(permission_name) = 'SELECT';

if @TABLE_PERMISSION_COUNT >= 2 begin exec(
    'INSERT INTO #FeaturesEnabled
        SELECT
        ''MaintenancePlansEnabled'',
        CASE WHEN COALESCE(count(*),0) > 0
            THEN ''1''
            ELSE ''0''
        END,
        CASE WHEN COALESCE(count(*),0) > 0
            THEN COALESCE(count(*),0)
            ELSE 0
        END
    FROM
        msdb..sysmaintplan_plans p
        INNER JOIN msdb..sysmaintplan_subplans sp ON p.id = sp.plan_id
        INNER JOIN msdb..sysjobs j ON sp.job_id = j.job_id
    WHERE
        j.[enabled] = 1'
);

end;

else begin exec(
    'INSERT INTO #FeaturesEnabled VALUES (''MaintenancePlansEnabled'', ''0'', 0)'
);

end;

--Polybase Enabled
begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsPolybaseEnabled'',
        CONVERT(nvarchar, value_in_use),
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''polybase enabled'''
);

end;

--Resource Governor
begin exec (
    'INSERT INTO #FeaturesEnabled
    SELECT
        ''IsResourceGovernorEnabled'',
        CONVERT(nvarchar, is_enabled),
        CASE
            WHEN is_enabled > 0 THEN 1
            ELSE 0
        END
    FROM sys.resource_governor_configuration'
);

end;

--Stretch Database
if @CLOUDTYPE = 'AZURE' begin exec(
    'INSERT INTO #FeaturesEnabled
            SELECT
                ''IsStretchDatabaseEnabled'',
                CONVERT(nvarchar, count(*)),
                CONVERT(int, count(*))
            FROM sys.remote_data_archive_databases'
);

end if @CLOUDTYPE = 'NONE' begin if @PRODUCT_VERSION >= 13
and @PRODUCT_VERSION <= 16 begin exec(
    'INSERT INTO #FeaturesEnabled
                SELECT
                    ''IsStretchDatabaseEnabled'',
                    CONVERT(nvarchar, count(*)),
                    CONVERT(int, count(*))
                FROM sys.remote_data_archive_databases /* SQL Server 2016 (13.x) and Up to 2022 */'
);

end
else begin exec(
    'INSERT INTO #FeaturesEnabled VALUES (''IsStretchDatabaseEnabled'', ''0'', 0)'
);

end
end --TDE in Use
begin exec(
    'INSERT INTO #FeaturesEnabled
            SELECT
                ''IsTDEInUse'',
                CONVERT(nvarchar, count(*)),
                CONVERT(int, count(*))
            FROM sys.databases
            WHERE is_encrypted <> 0'
);

end --TempDB Metadata Memory Optimized
begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''IsTempDbMetadataMemoryOptimized'',
        CONVERT(nvarchar, value_in_use),
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''tempdb metadata memory-optimized'''
);

end;

--Sysadmin role
begin with check_sysadmin_role as (
    select name,
        type_desc,
        is_disabled
    from sys.server_principals
    where IS_SRVROLEMEMBER ('sysadmin', name) = 1
        and name not like '%NT SERVICE%'
        and name <> 'sa'
    union
    select name,
        type_desc,
        is_disabled
    from sys.server_principals
    where IS_SRVROLEMEMBER ('dbcreator', name) = 1
        and name not like '%NT SERVICE%'
        and name <> 'sa'
)
insert into #FeaturesEnabled
select 'sysadmin_role',
    case
        when count(*) > 0 then '1'
        else '0'
    end,
    case
        when count(*) > 0 then count(*)
        else 0
    end
from check_sysadmin_role;

end;

--Server level triggers
begin begin TRY exec(
    'INSERT INTO #FeaturesEnabled
                SELECT
                    ''ServerLevelTriggers'',
                    CASE
                        WHEN count(*) > 0
                        THEN ''1''
                        ELSE ''0''
                    END,
                    CONVERT(int, count(*))
                from sys.server_triggers'
);

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 exec(
    'INSERT INTO #FeaturesEnabled
                    SELECT
                        ''ServerLevelTriggers'',
                        ''0'',
                        0 '
);

end CATCH
end;

--OPENROWSET
begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''OPENROWSET'',
        CONVERT(nvarchar, value_in_use) ,
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''Ad Hoc Distributed Queries'''
);

end;

--ad hoc distributed queries / distributed transaction coordinator DTC
begin exec(
    '
    INSERT INTO #FeaturesEnabled
    SELECT
        ''ad hoc distributed queries'',
        CONVERT(nvarchar, value_in_use) ,
        CASE
            WHEN value_in_use > 0 THEN 1
            ELSE 0
        END
    FROM sys.configurations
    WHERE name = ''Ad Hoc Distributed Queries'''
);

end;

--BULK INSERT
insert into #FeaturesEnabled
select 'BULK_INSERT',
    case
        when count(p.permission_name) > 0 then '1'
        else '0'
    end,
    convert(int, count(p.permission_name))
from fn_my_permissions(null, 'SERVER') p
where permission_name like '%ADMINISTER BULK OPERATIONS%';

-- CountServiceBrokerEndpoints
begin TRY exec(
    'INSERT INTO #FeaturesEnabled
            SELECT
                ''CountServiceBrokerEndpoints'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.service_broker_endpoints'
);

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 exec(
    'INSERT INTO #FeaturesEnabled SELECT ''CountServiceBrokerEndpoints'', ''0'', 0'
);

end CATCH -- CountTSQLEndpoints
begin TRY exec(
    'INSERT INTO #FeaturesEnabled
            SELECT
                ''CountTSQLEndpoints'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.tcp_endpoints
            WHERE endpoint_id > 65535'
);

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 begin exec(
    'INSERT INTO #FeaturesEnabled SELECT ''CountTSQLEndpoints'', ''0'', 0'
);

end
else begin exec(
    'INSERT INTO #FeaturesEnabled SELECT ''CountTSQLEndpoints'', ''0'', 0'
);

end
end CATCH
/* Collect permissions which are unsupported in CloudSQL SQL Server */
begin begin TRY exec(
    'INSERT INTO #FeaturesEnabled
                SELECT
                    tmp.permission_name,
					CASE WHEN count(1) > 0 THEN 1 ELSE 0 END,
                    count(1)
                FROM (
                    SELECT
                        pr.name,
                        pr.type,
                        pr.type_desc,
                        p.permission_name,
                        p.type AS permission_type
                    FROM
                        sys.server_permissions p
                        INNER JOIN sys.server_principals pr ON p.grantee_principal_id = pr.principal_id
                    WHERE
                        pr.name NOT LIKE ''NT SERVICE\%''
                        AND name NOT LIKE ''##MS_%##''
                        AND pr.is_fixed_role <> 1
                        AND p.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'', 
                        ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'', 
                        ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'', 
                        ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'', 
                        ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')
					UNION ALL
                    SELECT
                        pr.name,
                        pr.type,
                        pr.type_desc,
                        dp.permission_name,
                        dp.type AS permission_type
                    FROM
                        sys.database_permissions dp
                        INNER JOIN sys.server_principals pr ON dp.grantee_principal_id = pr.principal_id
                    WHERE
                        pr.name NOT LIKE ''NT SERVICE\%''
                        AND name NOT LIKE ''##MS_%##''
                        AND pr.is_fixed_role <> 1
                        AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'', 
                        ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'', 
                        ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'', 
                        ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'', 
                        ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')     
                    ) tmp
                GROUP BY
                    tmp.permission_name'
);

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 begin TRY exec(
    'INSERT INTO #FeaturesEnabled
                        SELECT
                            tmp.permission_name,
                            CASE WHEN count(1) > 0 THEN 1 ELSE 0 END,
                            count(1)
                        FROM (
                            SELECT
                                pr.name,
                                pr.type,
                                pr.type_desc,
                                dp.permission_name,
                                dp.type AS permission_type
                            FROM
                                sys.database_permissions dp
                                INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
                            WHERE
                                pr.name NOT LIKE ''NT SERVICE\%''
                                AND name NOT LIKE ''##MS_%##''
                                AND pr.is_fixed_role <> 1
                                AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'', 
                                ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'', 
                                ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'', 
                                ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'', 
                                ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')) tmp
                        GROUP BY
                            tmp.permission_name'
);

end TRY begin CATCH if ERROR_NUMBER() = 208
and ERROR_SEVERITY() = 16
and ERROR_STATE() = 1 exec(
    '
                        INSERT INTO #FeaturesEnabled values (''ADMINISTER BULK OPERATIONS'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER ANY CREDENTIAL'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER ANY EVENT NOTIFICATION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER ANY EVENT SESSION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER RESOURCES'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''ALTER SETTINGS'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''AUTHENTICATE SERVER'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CONTROL SERVER'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE ASSEMBLY'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE DDL EVENT NOTIFICATION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE ENDPOINT'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''CREATE TRACE EVENT NOTIFICATION'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''EXTERNAL ACCESS ASSEMBLY'',''0'',0);
                        INSERT INTO #FeaturesEnabled values (''SHUTDOWN'',''0'',0);

                    ');
            END CATCH
    END CATCH
END

--Service Broker tasks
declare @ServBrokerTasksUsed as INT,
    @IS_ServBrokerTasksUsed as NVARCHAR(4);

select @ServBrokerTasksUsed = count(*)
from sys.dm_broker_activated_tasks;

if @ServBrokerTasksUsed > 0
set @IS_ServBrokerTasksUsed = '1'
    else
set @IS_ServBrokerTasksUsed = '0';

insert into #FeaturesEnabled
values (
        'Service Broker Tasks Used',
        @IS_ServBrokerTasksUsed,
        ISNULL(@ServBrokerTasksUsed, 0)
    );

--External Assemblies
if @CLOUDTYPE = 'AZURE' begin
insert into #FeaturesEnabled
values ('External Assemblies Used', '0', 0);

end
else begin
declare @ExternalAssembliesUsed as INT,
    @IS_ExternalAssembliesUsed as NVARCHAR(4);

select @ExternalAssembliesUsed = count(*)
from sys.server_permissions
where permission_name = 'External access assembly'
    and state = 'G';

if @ExternalAssembliesUsed > 0
set @IS_ExternalAssembliesUsed = '1'
    else
set @IS_ExternalAssembliesUsed = '0';

insert into #FeaturesEnabled
values (
        'External Assemblies Used',
        @IS_ExternalAssembliesUsed,
        ISNULL(@ExternalAssembliesUsed, 0)
    );

end --CLR Enabled
begin exec(
    'INSERT INTO #FeaturesEnabled
        SELECT ''IsCLREnabled'',
        CONVERT(nvarchar, value_in_use),
        CONVERT(int, value_in_use)
        FROM sys.configurations
        WHERE name = ''clr enabled'''
);

end --Linked Servers
if @CLOUDTYPE = 'AZURE' begin
insert into #FeaturesEnabled
values ('IsLinkedServersUsed', '0', 0);

end
else begin exec(
    'INSERT INTO #FeaturesEnabled
    SELECT ''IsLinkedServersUsed'',
            count(*),
            count(*)
    FROM sys.servers
    WHERE is_linked = 1'
);

end --Policy based management
begin TRY exec(
    'DECLARE @PoliciesEnabled_value as INT, @IS_PoliciesEnabled as NVARCHAR(4);
        SELECT @PoliciesEnabled_value = count(*) FROM msdb.dbo.syspolicy_policies where is_enabled =1;
	        IF @PoliciesEnabled_value > 0 SET @IS_PoliciesEnabled = ''1''  ELSE  SET @IS_PoliciesEnabled = ''0'' ;
	        INSERT INTO #FeaturesEnabled VALUES (
		        ''Policy-Based Management'', @IS_PoliciesEnabled, ISNULL(@PoliciesEnabled_value,0) );'
);

end TRY begin CATCH if ERROR_NUMBER() = 40515
and ERROR_SEVERITY() = 15
and ERROR_STATE() = 1 exec(
    'INSERT INTO #FeaturesEnabled VALUES (''Policy-Based Management'', ''0'', 0)'
)
end CATCH
/* Certain clouds do not allow access to certain tables so we need to catch the table does not exist error and default the setting */
begin begin TRY exec(
    'INSERT INTO #FeaturesEnabled SELECT ''IsBufferPoolExtensionEnabled'',
                  CASE
                    WHEN state = 0 THEN ''0''
                    WHEN state = 1 THEN ''0''
                    WHEN state = 2 THEN ''1''
                    WHEN state = 3 THEN ''1''
                    WHEN state = 4 THEN ''1''
                    WHEN state = 5 THEN ''1''
                    ELSE ''0''
                  END,
                  CASE WHEN state > 0 THEN 1 ELSE 0 END
                  FROM sys.dm_os_buffer_pool_extension_configuration /* SQL Server 2014 (13.x) above */'
);

SELECT
    QUOTENAME(@PKEY,'"') as PKEY,
    QUOTENAME(f.Features,'"') as Features,
    QUOTENAME(f.Is_EnabledOrUsed,'"') as Is_EnabledOrUsed,
    QUOTENAME(f.Count,'"') as Count ,
    QUOTENAME(@DMA_SOURCE_ID,'"') as dma_source_id,
    QUOTENAME(@DMA_MANUAL_ID,'"') as dma_manual_id
FROM #FeaturesEnabled f;

IF OBJECT_ID('tempdb..#FeaturesEnabled') IS NOT NULL  
   DROP TABLE #FeaturesEnabled;

IF OBJECT_ID('tempdb..#myPerms') IS NOT NULL  
   DROP TABLE #myPerms;
