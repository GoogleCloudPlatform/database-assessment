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
DECLARE @PRODUCT_VERSION AS INTEGER
DECLARE @TABLE_PERMISSION_COUNT AS INTEGER
DECLARE @ROW_COUNT_VAR AS INTEGER
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @CLOUDTYPE = 'NONE';
SELECT @PRODUCT_VERSION = CONVERT(INTEGER, PARSENAME(CONVERT(NVARCHAR(255), SERVERPROPERTY('productversion')), 4));
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF UPPER(@@VERSION) LIKE '%AZURE%'
	SELECT @CLOUDTYPE = 'AZURE'

IF OBJECT_ID('tempdb..#FeaturesEnabledDbLevel') IS NOT NULL
   DROP TABLE #FeaturesEnabledDbLevel;

CREATE TABLE #FeaturesEnabledDbLevel
(
    database_name nvarchar(255) DEFAULT db_name(),
    feature_name NVARCHAR(255),
    is_enabled_or_used NVARCHAR(255),
    occurance_count INT
);

--Security Policies
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''SP'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.security_policies
            WHERE is_enabled = 1') /* SQL Server 2016 (13.x) and above */ ;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SP'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
    ELSE
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SP'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
END CATCH

--File Tables Detected
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''IsFileTablesEnabled'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.filetables
            WHERE is_enabled = 1') /* SQL Server 2016 (13.x) and above */ ;
END TRY
BEGIN CATCH
    IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsFileTablesEnabled'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
    ELSE
    BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsFileTablesEnabled'', ''0'', 0')
/* SQL Server 2014 (12.x) and below */
;
END
END CATCH

--Real-Time Operational Analytics (Nonclustered Columnstore Index on Rowstore/In-Memory Table)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''RealTimeOperationalAnalyticsUsed'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.indexes i
            INNER JOIN sys.tables t ON i.object_id = t.object_id
            WHERE i.type = 6
              AND t.is_ms_shipped = 0');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''RealTimeOperationalAnalyticsUsed'', ''0'', 0');
END CATCH

--User Certificates (PFX / Private-Key Backed Certificates)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''UserCertificatesUsed'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.certificates
            WHERE name NOT LIKE ''##MS_%''
              AND pvt_key_encryption_type <> ''NA''');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''UserCertificatesUsed'', ''0'', 0');
END CATCH

--RESTORE Statements in User SQL Modules
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT
                db_name(),
                ''RESTORE'',
                CASE
                    WHEN count(*) > 0 THEN ''1''
                    ELSE ''0''
                END,
                CONVERT(int, count(*))
            FROM sys.sql_modules m
            INNER JOIN sys.objects o ON m.object_id = o.object_id
            WHERE o.is_ms_shipped = 0
              AND (
                  UPPER(m.definition) LIKE ''%RESTORE DATABASE%''
                  OR UPPER(m.definition) LIKE ''%RESTORE LOG%''
                  OR UPPER(m.definition) LIKE ''%RESTORE HEADERONLY%''
                  OR UPPER(m.definition) LIKE ''%RESTORE FILELISTONLY%''
              )');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''RESTORE'', ''0'', 0');
END CATCH

/* Collect permissions which are unsupported in CloudSQL SQL Server */
BEGIN
    BEGIN TRY
            exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT
                    db_name(),
                    tmp.permission_name,
					CASE WHEN count(1) > 0 THEN ''1'' ELSE ''0'' END,
                    count(1)
                FROM (
                    SELECT
                        pr.name,
                        pr.type,
                        pr.type_desc,
                        CASE
                            WHEN dp.permission_name = ''ADMINISTER DATABASE BULK OPERATIONS'' THEN ''ADMINISTER BULK OPERATIONS''
                            ELSE dp.permission_name
                        END AS permission_name,
                        dp.type AS permission_type
                    FROM
                        sys.database_permissions dp
                        INNER JOIN sys.database_principals pr ON dp.grantee_principal_id = pr.principal_id
                    WHERE
                        dp.state IN (''G'', ''W'')
                        AND pr.name NOT LIKE ''NT SERVICE\%''
                        AND pr.name NOT LIKE ''NT AUTHORITY\%''
                        AND pr.name NOT LIKE ''##MS_%##''
                        AND pr.name NOT IN (''dbo'', ''guest'', ''INFORMATION_SCHEMA'', ''sys'', ''public'')
                        AND pr.is_fixed_role <> 1
                        AND dp.permission_name IN (''ADMINISTER BULK OPERATIONS'', ''ADMINISTER DATABASE BULK OPERATIONS'', ''ALTER ANY CREDENTIAL'',
                        ''ALTER ANY EVENT NOTIFICATION'', ''ALTER ANY EVENT SESSION'', ''ALTER RESOURCES'',
                        ''ALTER SETTINGS'', ''AUTHENTICATE SERVER'', ''CONTROL SERVER'',
                        ''CREATE DDL EVENT NOTIFICATION'', ''CREATE ENDPOINT'', ''CREATE TRACE EVENT NOTIFICATION'',
                        ''EXTERNAL ACCESS ASSEMBLY'', ''SHUTDOWN'', ''EXTERNAL ASSEMBLIES'', ''CREATE ASSEMBLY'')) tmp
                GROUP BY
                    tmp.permission_name');
    END TRY
    BEGIN CATCH
        IF ERROR_NUMBER() = 208 AND ERROR_SEVERITY() = 16 AND ERROR_STATE() = 1
            WAITFOR DELAY '00:00:00'
    END CATCH
END

/* ------------------------------------------------------------------------------------------------
   Coverage-gap rows (DMA 2.0 parity). Naming convention shared with the DMA 2.0 collector:
   a feature name starting with "Is" carries 0/1 in is_enabled_or_used, a plain noun carries the
   count in both is_enabled_or_used and occurance_count, and a text-valued row (…Desc,
   OwnerLoginType) carries the value in is_enabled_or_used with occurance_count = 0. Every block
   falls back to ('0', 0) when the catalog object is absent or not readable.
   ------------------------------------------------------------------------------------------------ */

--Database audit specifications (enabled)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DatabaseAuditSpecifications'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_audit_specifications
            WHERE is_state_enabled = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseAuditSpecifications'', ''0'', 0');
END CATCH

--Database diagrams (dbo.sysdiagrams exists only where diagrams were created)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DatabaseDiagrams'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.sysdiagrams');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseDiagrams'', ''0'', 0');
END CATCH

--Natively compiled modules (SQL Server 2014 (12.x) and later)
IF @PRODUCT_VERSION >= 12
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''NativelyCompiledModules'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
                FROM sys.sql_modules
                WHERE uses_native_compilation = 1');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''NativelyCompiledModules'', ''0'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''NativelyCompiledModules'', ''0'', 0');
END

--Plan guides (enabled)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''PlanGuides'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.plan_guides
            WHERE is_disabled = 0');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''PlanGuides'', ''0'', 0');
END CATCH

--Database scoped credentials (SQL Server 2016 (13.x) and later)
IF @PRODUCT_VERSION >= 13 OR CONVERT(INT, SERVERPROPERTY('EngineEdition')) = 5
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''DatabaseScopedCredentials'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
                FROM sys.database_scoped_credentials');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseScopedCredentials'', ''0'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseScopedCredentials'', ''0'', 0');
END

--Synonyms pointing outside this database / outside this server
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''SynonymsCrossDatabase'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.synonyms
            WHERE PARSENAME(base_object_name, 4) IS NULL
              AND PARSENAME(base_object_name, 3) IS NOT NULL
              AND PARSENAME(base_object_name, 3) <> DB_NAME()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SynonymsCrossDatabase'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''SynonymsCrossServer'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.synonyms
            WHERE PARSENAME(base_object_name, 4) IS NOT NULL');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SynonymsCrossServer'', ''0'', 0');
END CATCH

--Transactional / snapshot publications (dbo.syspublications exists only in published databases;
-- repl_freq 0 = transactional, 1 = snapshot; options & 0x1 = enabled for peer-to-peer)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''TransactionalPublications'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.syspublications
            WHERE repl_freq = 0');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''TransactionalPublications'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''SnapshotPublications'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.syspublications
            WHERE repl_freq = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SnapshotPublications'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''PeerToPeerPublications'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.syspublications
            WHERE (ISNULL(options, 0) & 1) = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''PeerToPeerPublications'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''PublicationsAllowingPull'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.syspublications
            WHERE allow_pull = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''PublicationsAllowingPull'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''UpdatableSubscriptionPublications'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.syspublications
            WHERE allow_sync_tran = 1
               OR allow_queued_tran = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''UpdatableSubscriptionPublications'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''TransactionalArticles'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.sysarticles
            WHERE EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND is_published = 1)');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''TransactionalArticles'', ''0'', 0');
END CATCH

--Merge publications and articles (dbo.sysmergepublications also exists on merge subscribers, so the
-- sys.databases is_merge_published flag gates the publisher-side counts)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''MergePublications'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.sysmergepublications
            WHERE EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND is_merge_published = 1)');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''MergePublications'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''MergeArticles'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM dbo.sysmergearticles
            WHERE EXISTS (SELECT 1 FROM sys.databases WHERE database_id = DB_ID() AND is_merge_published = 1)');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''MergeArticles'', ''0'', 0');
END CATCH

--Merge subscriber role: sys.databases has no merge-subscriber flag, so this database counts as a merge
-- subscriber when dbo.sysmergesubscriptions lists it against a publication it does not own itself
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsMergeSubscribed'',
                   CASE WHEN count(*) > 0 THEN ''1'' ELSE ''0'' END,
                   CONVERT(int, count(*))
            FROM dbo.sysmergesubscriptions ss
            INNER JOIN dbo.sysmergepublications sp ON ss.pubid = sp.pubid
            WHERE ss.db_name = DB_NAME()
              AND UPPER(ss.subscriber_server) = UPPER(CONVERT(NVARCHAR(128), @@SERVERNAME))
              AND NOT (sp.publisher_db = DB_NAME() AND UPPER(sp.publisher) = UPPER(CONVERT(NVARCHAR(128), @@SERVERNAME)))');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsMergeSubscribed'', ''0'', 0');
END CATCH

--Database users by type (no names are emitted)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DatabaseUsersWindows'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_principals
            WHERE type = ''U''');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseUsersWindows'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DatabaseUsersWindowsGroup'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_principals
            WHERE type = ''G''');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseUsersWindowsGroup'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DatabaseUsersCertificate'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_principals
            WHERE type = ''C''
              AND name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseUsersCertificate'', ''0'', 0');
END CATCH

--Contained users (authentication_type 2 = DATABASE, 3 = WINDOWS without login, 4 = EXTERNAL; SQL Server 2012 (11.x) and later)
IF @PRODUCT_VERSION >= 11
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''DatabaseUsersContained'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
                FROM sys.database_principals
                WHERE type IN (''S'', ''U'', ''G'', ''E'', ''X'')
                  AND authentication_type IN (2, 3, 4)');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseUsersContained'', ''0'', 0');
    END CATCH

    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''OrphanedSqlUsers'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
                FROM sys.database_principals dp
                LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
                WHERE dp.type = ''S''
                  AND dp.principal_id > 4
                  AND dp.name NOT LIKE ''##MS_%''
                  AND dp.authentication_type = 1
                  AND sp.sid IS NULL');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''OrphanedSqlUsers'', ''0'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DatabaseUsersContained'', ''0'', 0');

    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''OrphanedSqlUsers'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
                FROM sys.database_principals dp
                LEFT JOIN sys.server_principals sp ON dp.sid = sp.sid
                WHERE dp.type = ''S''
                  AND dp.principal_id > 4
                  AND dp.name NOT LIKE ''##MS_%''
                  AND dp.sid IS NOT NULL
                  AND sp.sid IS NULL');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''OrphanedSqlUsers'', ''0'', 0');
    END CATCH
END

--Encryption keys in this database (database master key excluded)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''SymmetricKeys'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.symmetric_keys
            WHERE name NOT LIKE ''##MS_%''');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''SymmetricKeys'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''AsymmetricKeys'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.asymmetric_keys');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''AsymmetricKeys'', ''0'', 0');
END CATCH

--File layout (counts only; no paths are emitted)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DataFiles'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_files
            WHERE type = 0');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DataFiles'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''LogFiles'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_files
            WHERE type = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''LogFiles'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''Filegroups'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.filegroups');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''Filegroups'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''ReadOnlyFilegroups'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.filegroups
            WHERE is_read_only = 1');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''ReadOnlyFilegroups'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''FilesWithPercentGrowth'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_files
            WHERE is_percent_growth = 1
              AND growth > 0');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''FilesWithPercentGrowth'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''FilesOnNonDefaultDrives'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.database_files f
            WHERE UPPER(LEFT(f.physical_name, 1)) <> (
                SELECT TOP 1 UPPER(LEFT(physical_name, 1))
                FROM sys.database_files
                GROUP BY UPPER(LEFT(physical_name, 1))
                ORDER BY COUNT(*) DESC, UPPER(LEFT(physical_name, 1)))');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''FilesOnNonDefaultDrives'', ''0'', 0');
END CATCH

--Distributed transactions started inside user modules
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''DistributedTransactionsInModules'', CONVERT(NVARCHAR(255), count(*)), CONVERT(int, count(*))
            FROM sys.sql_modules m
            INNER JOIN sys.objects o ON m.object_id = o.object_id
            WHERE o.is_ms_shipped = 0
              AND UPPER(m.definition) LIKE ''%BEGIN DISTRIBUTED TRAN%''');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DistributedTransactionsInModules'', ''0'', 0');
END CATCH

--sys.databases options for this database as boolean rows (SQL Server 2008 and later)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsTrustworthyOn'', CONVERT(NVARCHAR(255), CONVERT(int, is_trustworthy_on)), CONVERT(int, is_trustworthy_on)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsTrustworthyOn'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsDbChainingOn'', CONVERT(NVARCHAR(255), CONVERT(int, is_db_chaining_on)), CONVERT(int, is_db_chaining_on)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsDbChainingOn'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsReadCommittedSnapshotOn'', CONVERT(NVARCHAR(255), CONVERT(int, is_read_committed_snapshot_on)), CONVERT(int, is_read_committed_snapshot_on)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsReadCommittedSnapshotOn'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsAutoCloseOn'', CONVERT(NVARCHAR(255), CONVERT(int, is_auto_close_on)), CONVERT(int, is_auto_close_on)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsAutoCloseOn'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsAutoShrinkOn'', CONVERT(NVARCHAR(255), CONVERT(int, is_auto_shrink_on)), CONVERT(int, is_auto_shrink_on)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsAutoShrinkOn'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsDatabaseSnapshot'',
                   CASE WHEN source_database_id IS NOT NULL THEN ''1'' ELSE ''0'' END,
                   CASE WHEN source_database_id IS NOT NULL THEN 1 ELSE 0 END
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsDatabaseSnapshot'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsPublished'', CONVERT(NVARCHAR(255), CONVERT(int, is_published)), CONVERT(int, is_published)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsPublished'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsSubscribed'', CONVERT(NVARCHAR(255), CONVERT(int, is_subscribed)), CONVERT(int, is_subscribed)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsSubscribed'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsMergePublished'', CONVERT(NVARCHAR(255), CONVERT(int, is_merge_published)), CONVERT(int, is_merge_published)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsMergePublished'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsDistributor'', CONVERT(NVARCHAR(255), CONVERT(int, is_distributor)), CONVERT(int, is_distributor)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsDistributor'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsReadOnly'', CONVERT(NVARCHAR(255), CONVERT(int, is_read_only)), CONVERT(int, is_read_only)
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsReadOnly'', ''0'', 0');
END CATCH

--Database owner: sa (SID 0x01) and the owning login type (no login name is emitted)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''IsOwnerSa'',
                   CASE WHEN owner_sid = 0x01 THEN ''1'' ELSE ''0'' END,
                   CASE WHEN owner_sid = 0x01 THEN 1 ELSE 0 END
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsOwnerSa'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''OwnerLoginType'', ISNULL(CONVERT(NVARCHAR(255), sp.type_desc), ''NO_MATCHING_LOGIN''), 0
            FROM sys.databases d
            LEFT JOIN sys.server_principals sp ON d.owner_sid = sp.sid
            WHERE d.database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''OwnerLoginType'', ''0'', 0');
END CATCH

--sys.databases text-valued options for this database (value carried in is_enabled_or_used)
BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''LogReuseWaitDesc'', ISNULL(CONVERT(NVARCHAR(255), log_reuse_wait_desc), ''0''), 0
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''LogReuseWaitDesc'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''PageVerifyOptionDesc'', ISNULL(CONVERT(NVARCHAR(255), page_verify_option_desc), ''0''), 0
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''PageVerifyOptionDesc'', ''0'', 0');
END CATCH

BEGIN TRY
    exec('INSERT INTO #FeaturesEnabledDbLevel
            SELECT db_name(), ''UserAccessDesc'', ISNULL(CONVERT(NVARCHAR(255), user_access_desc), ''0''), 0
            FROM sys.databases WHERE database_id = DB_ID()');
END TRY
BEGIN CATCH
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''UserAccessDesc'', ''0'', 0');
END CATCH

--Containment (SQL Server 2012 (11.x) and later; earlier versions have no containment)
IF @PRODUCT_VERSION >= 11
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''ContainmentDesc'', ISNULL(CONVERT(NVARCHAR(255), containment_desc), ''NONE''), 0
                FROM sys.databases WHERE database_id = DB_ID()');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''ContainmentDesc'', ''NONE'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''ContainmentDesc'', ''NONE'', 0');
END

--Delayed durability (SQL Server 2014 (12.x) and later; earlier versions behave as DISABLED)
IF @PRODUCT_VERSION >= 12
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''DelayedDurabilityDesc'', ISNULL(CONVERT(NVARCHAR(255), delayed_durability_desc), ''DISABLED''), 0
                FROM sys.databases WHERE database_id = DB_ID()');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DelayedDurabilityDesc'', ''DISABLED'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''DelayedDurabilityDesc'', ''DISABLED'', 0');
END

--Stretch Database per database (SQL Server 2016 (13.x) and later)
IF @PRODUCT_VERSION >= 13 OR CONVERT(INT, SERVERPROPERTY('EngineEdition')) = 5
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''IsRemoteDataArchiveEnabled'', CONVERT(NVARCHAR(255), CONVERT(int, ISNULL(is_remote_data_archive_enabled, 0))), CONVERT(int, ISNULL(is_remote_data_archive_enabled, 0))
                FROM sys.databases WHERE database_id = DB_ID()');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsRemoteDataArchiveEnabled'', ''0'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsRemoteDataArchiveEnabled'', ''0'', 0');
END

--Accelerated Database Recovery (SQL Server 2019 (15.x) and later)
IF @PRODUCT_VERSION >= 15 OR CONVERT(INT, SERVERPROPERTY('EngineEdition')) = 5
BEGIN
    BEGIN TRY
        exec('INSERT INTO #FeaturesEnabledDbLevel
                SELECT db_name(), ''IsAcceleratedDatabaseRecoveryOn'', CONVERT(NVARCHAR(255), CONVERT(int, ISNULL(is_accelerated_database_recovery_on, 0))), CONVERT(int, ISNULL(is_accelerated_database_recovery_on, 0))
                FROM sys.databases WHERE database_id = DB_ID()');
    END TRY
    BEGIN CATCH
        exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsAcceleratedDatabaseRecoveryOn'', ''0'', 0');
    END CATCH
END
ELSE
BEGIN
    exec('INSERT INTO #FeaturesEnabledDbLevel SELECT db_name(), ''IsAcceleratedDatabaseRecoveryOn'', ''0'', 0');
END

SELECT
    '"' + @PKEY + '"' as PKEY,
    '"' + CONVERT(NVARCHAR(MAX), f.database_name) + '"' as database_name,
    '"' + CONVERT(NVARCHAR(MAX), f.feature_name) + '"' as feature_name,
    '"' + CONVERT(NVARCHAR(MAX), f.is_enabled_or_used) + '"' as is_enabled_or_used,
    '"' + CONVERT(NVARCHAR(MAX), f.occurance_count) + '"' as occurance_count,
    '"' + @DMA_SOURCE_ID + '"' as dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' as dma_manual_id
FROM #FeaturesEnabledDbLevel f;

IF OBJECT_ID('tempdb..#FeaturesEnabledDbLevel') IS NOT NULL
   DROP TABLE #FeaturesEnabledDbLevel;
