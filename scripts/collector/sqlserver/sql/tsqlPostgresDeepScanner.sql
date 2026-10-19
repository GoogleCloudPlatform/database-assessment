/*
-- Author: Tim Chapman
Copyright 2026 Google LLC

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
DECLARE @DMA_SOURCE_ID AS VARCHAR(256)
DECLARE @DMA_MANUAL_ID AS VARCHAR(256)

SELECT @PKEY = N'$(pkey)';
SELECT @DMA_SOURCE_ID = N'$(dmaSourceId)';
SELECT @DMA_MANUAL_ID = N'$(dmaManualId)';

IF OBJECT_ID('tempdb..#BlockerPatterns') IS NOT NULL
    DROP TABLE #BlockerPatterns;

CREATE TABLE #BlockerPatterns (
    Pattern NVARCHAR(100),
    IncompatibilityType NVARCHAR(50),
    Severity NVARCHAR(20)
);

INSERT INTO #BlockerPatterns VALUES
-- Query & Locking Hints
('%NOLOCK%', 'HINT_NOLOCK', 'MEDIUM'),
('%READUNCOMMITTED%', 'HINT_READUNCOMMITTED', 'MEDIUM'),
('%TABLOCK%', 'HINT_TABLE_LOCK', 'HIGH'),
('%UPDLOCK%', 'HINT_UPDATE_LOCK', 'HIGH'),
('%XLOCK%', 'HINT_EXCLUSIVE_LOCK', 'HIGH'),
('%ROWLOCK%', 'HINT_ROW_LOCK', 'MEDIUM'),
('%PAGLOCK%', 'HINT_PAGE_LOCK', 'HIGH'),
('%FORCESEEK%', 'HINT_FORCE_SEEK', 'HIGH'),
('%FORCESCAN%', 'HINT_FORCE_SCAN', 'HIGH'),
('%RECOMPILE%', 'HINT_RECOMPILE', 'HIGH'),
('%OPTIMIZE FOR%', 'HINT_OPTIMIZE_FOR', 'HIGH'),
('%MAXDOP%', 'HINT_MAXDOP', 'HIGH'),
('%KEEPPLAN%', 'HINT_KEEP_PLAN', 'MEDIUM'),
('%KEEPFIXED PLAN%', 'HINT_KEEPFIXED_PLAN', 'MEDIUM'),
('%FAST %', 'HINT_FAST_N', 'MEDIUM'),

-- Operators
('%CROSS APPLY%', 'OPERATOR_CROSS_APPLY', 'HIGH'),
('%OUTER APPLY%', 'OPERATOR_OUTER_APPLY', 'HIGH'),

-- Functions
('%DATEADD(%', 'FUNC_DATEADD', 'LOW'),
('%DATEDIFF(%', 'FUNC_DATEDIFF', 'LOW'),
('%DATENAME(%', 'FUNC_DATENAME', 'LOW'),
('%DATEPART(%', 'FUNC_DATEPART', 'LOW'),
('%GETDATE(%', 'FUNC_GETDATE', 'LOW'),
('%SYSDATETIME(%', 'FUNC_SYSDATETIME', 'LOW'),
('%ISNULL(%', 'FUNC_ISNULL', 'LOW'),
('%IIF(%', 'FUNC_IIF', 'LOW'),
('%CHOOSE(%', 'FUNC_CHOOSE', 'MEDIUM'),
('%ISNUMERIC(%', 'FUNC_ISNUMERIC', 'MEDIUM'),
('%STUFF(%', 'FUNC_STUFF', 'MEDIUM'),
('%TRY_CONVERT(%', 'FUNC_TRY_CONVERT', 'HIGH'),
('%TRY_CAST(%', 'FUNC_TRY_CAST', 'HIGH'),
('%TRY_PARSE(%', 'FUNC_TRY_PARSE', 'HIGH'),

-- Dynamic SQL & OLE
('%EXEC(%', 'EXEC_DYNAMIC_SQL', 'CRITICAL'),
('%EXECUTE(%', 'EXEC_DYNAMIC_SQL', 'CRITICAL'),
('%sp[_]executesql%', 'EXEC_SP_EXECUTESQL', 'CRITICAL'),
('%sp[_]OACreate%', 'OLE_AUTOMATION', 'CRITICAL'),
('%sp[_]OAMethod%', 'OLE_AUTOMATION', 'CRITICAL'),
('%sp[_]OASetProperty%', 'OLE_AUTOMATION', 'CRITICAL'),
('%sp[_]OAGetProperty%', 'OLE_AUTOMATION', 'CRITICAL'),

-- Extended Stored Procedures & OS Calls
('%xp[_]cmdshell%', 'EXTENDED_PROC_XP_CMDSHELL', 'CRITICAL'),
('%xp[_]sendmail%', 'EXTENDED_PROC_XP_SENDMAIL', 'HIGH'),
('%xp[_]dirtree%', 'EXTENDED_PROC_XP_DIRTREE', 'HIGH'),
('%xp[_]fileexist%', 'EXTENDED_PROC_XP_FILEEXIST', 'HIGH'),
('%xp[_]regread%', 'EXTENDED_PROC_XP_REGREAD', 'HIGH'),
('%xp[_]regwrite%', 'EXTENDED_PROC_XP_REGWRITE', 'HIGH'),
('%xp[_]%', 'EXTENDED_PROC_GENERIC', 'HIGH'),

-- Database Mail
('%sp[_]send[_]dbmail%', 'FEATURE_DATABASE_MAIL', 'HIGH'),
('%sp[_]notify[_]operator%', 'FEATURE_DATABASE_MAIL', 'HIGH'),

-- Identity
('%SET IDENTITY_INSERT%', 'SESSION_IDENTITY_INSERT', 'HIGH'),
('%@@IDENTITY%', 'IDENTITY_GLOBAL', 'MEDIUM'),
('%SCOPE_IDENTITY(%', 'IDENTITY_SCOPE', 'MEDIUM'),

-- Syntax
('%SELECT TOP %', 'SYNTAX_TOP', 'MEDIUM'),
('%MERGE INTO%', 'SYNTAX_MERGE', 'CRITICAL'),
('% PIVOT%', 'SYNTAX_PIVOT', 'CRITICAL'),
('% UNPIVOT%', 'SYNTAX_UNPIVOT', 'CRITICAL'),
('%GOTO %', 'SYNTAX_GOTO', 'CRITICAL'),

-- Legacy Joins (Non-ANSI Outer Joins)
('%*=%', 'SYNTAX_NON_ANSI_JOIN', 'HIGH'),
('%=*%', 'SYNTAX_NON_ANSI_JOIN', 'HIGH'),

-- Text Pointer Manipulation
('%WRITETEXT %', 'SYNTAX_TEXT_POINTER', 'CRITICAL'),
('%UPDATETEXT %', 'SYNTAX_TEXT_POINTER', 'CRITICAL'),
('%READTEXT %', 'SYNTAX_TEXT_POINTER', 'CRITICAL'),
('%TEXTPTR(%', 'SYNTAX_TEXT_POINTER', 'CRITICAL'),

-- XML & JSON
('%.nodes(%', 'XML_NODES', 'HIGH'),
('%.value(%', 'XML_VALUE', 'HIGH'),
('%.query(%', 'XML_QUERY', 'HIGH'),
('%JSON_VALUE(%', 'JSON_VALUE', 'MEDIUM'),
('%JSON_QUERY(%', 'JSON_QUERY', 'MEDIUM'),

-- Cursors
('%DECLARE % CURSOR %', 'CURSOR_DECLARE', 'CRITICAL'),
('%FETCH NEXT FROM%', 'CURSOR_FETCH', 'CRITICAL'),

-- CLR
('%EXTERNAL NAME%', 'CLR_ASSEMBLY', 'CRITICAL'),

-- Linked Servers
('%OPENQUERY(%', 'LINKED_SERVER_OPENQUERY', 'CRITICAL'),
('%OPENROWSET(%', 'LINKED_SERVER_OPENROWSET', 'CRITICAL'),
('%OPENDATASOURCE(%', 'LINKED_SERVER_OPENDATASOURCE', 'CRITICAL'),

-- Error Handling
('%RAISERROR%', 'ERROR_RAISERROR', 'MEDIUM'),
('%THROW %', 'ERROR_THROW', 'MEDIUM'),

-- Session
('%SET XACT_ABORT%', 'SESSION_XACT_ABORT', 'MEDIUM'),
('%SET DEADLOCK_PRIORITY%', 'SESSION_DEADLOCK_PRIORITY', 'HIGH'),
('%SET LOCK_TIMEOUT%', 'SESSION_LOCK_TIMEOUT', 'HIGH'),

-- Metadata & Legacy Catalog Views
('%sys.objects%', 'METADATA_SYS_OBJECTS', 'MEDIUM'),
('%sys.columns%', 'METADATA_SYS_COLUMNS', 'MEDIUM'),
('%sys.databases%', 'METADATA_SYS_DATABASES', 'MEDIUM'),
('%sys.tables%', 'METADATA_SYS_TABLES', 'MEDIUM'),
('%sys.sys%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysprocesses%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%syscomments%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%syslogins%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysusers%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysdepends%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysfilegroups%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysfiles%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysforeignkeys%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysindexes%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysindexkeys%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysmembers%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%syspermissions%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysprotects%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%sysreferences%', 'METADATA_LEGACY_CATALOG', 'HIGH'),
('%systypes%', 'METADATA_LEGACY_CATALOG', 'HIGH'),

-- Temp Tables
('%[^#]#[a-zA-Z_]%', 'TEMP_TABLE_LOCAL', 'HIGH'),
('%##%', 'TEMP_TABLE_GLOBAL', 'HIGH'),

-- MSDTC / Distributed Transactions
('%DISTRIBUTED TRANSACTION%', 'SYNTAX_DISTRIBUTED_TRANSACTION', 'CRITICAL'),
('%BEGIN DISTRIBUTED%', 'SYNTAX_DISTRIBUTED_TRANSACTION', 'CRITICAL');


IF OBJECT_ID('tempdb..#DetectedBlockers') IS NOT NULL
    DROP TABLE #DetectedBlockers;

CREATE TABLE #DetectedBlockers (
    database_name NVARCHAR(255),
    schema_name NVARCHAR(255),
    object_name NVARCHAR(255),
    object_type NVARCHAR(100),
    incompatibility_type NVARCHAR(100),
    severity NVARCHAR(20)
);

-- Part 1: Deep String Pattern Matching (sys.sql_modules)
INSERT INTO #DetectedBlockers
SELECT
    DB_NAME() AS database_name,
    s.name AS schema_name,
    o.name AS object_name,
    o.type_desc AS object_type,
    p.IncompatibilityType AS incompatibility_type,
    p.Severity AS severity
FROM sys.sql_modules m
INNER JOIN sys.objects o ON m.object_id = o.object_id
INNER JOIN sys.schemas s ON o.schema_id = s.schema_id
CROSS JOIN #BlockerPatterns p
WHERE m.definition LIKE p.Pattern
  AND o.is_ms_shipped = 0
  AND (
      p.IncompatibilityType <> 'EXTENDED_PROC_GENERIC'
      OR NOT EXISTS (
          SELECT 1
          FROM #BlockerPatterns p2
          WHERE p2.IncompatibilityType LIKE 'EXTENDED_PROC_XP_%'
            AND m.definition LIKE p2.Pattern
      )
  );

-- Part 2: Bulletproof Cross-Database 3-Part & 4-Part Name Dependencies
BEGIN TRY
    INSERT INTO #DetectedBlockers
    SELECT
        DB_NAME() AS database_name,
        OBJECT_SCHEMA_NAME(dep.referencing_id) AS schema_name,
        OBJECT_NAME(dep.referencing_id) AS object_name,
        o.type_desc AS object_type,
        CASE
            WHEN dep.referenced_server_name IS NOT NULL THEN 'LINKED_SERVER_4_PART_NAME'
            ELSE 'CROSS_DATABASE_3_PART_NAME'
        END AS incompatibility_type,
        'CRITICAL' AS severity
    FROM sys.sql_expression_dependencies dep
    INNER JOIN sys.objects o ON dep.referencing_id = o.object_id
    WHERE dep.referenced_database_name IS NOT NULL
      AND dep.referenced_database_name <> DB_NAME()
      AND o.is_ms_shipped = 0;
END TRY
BEGIN CATCH
    -- Gracefully skip Part 2 if the login lacks SELECT permission on sys.sql_expression_dependencies
END CATCH;

-- Inject EXPLICIT NONE_DETECTED row if 0 blockers exist in this DB
IF NOT EXISTS (SELECT 1 FROM #DetectedBlockers)
BEGIN
    INSERT INTO #DetectedBlockers VALUES (
        DB_NAME(), 'N/A', 'N/A', 'N/A', 'NONE_DETECTED', 'NONE'
    );
END;

-- Final Aggregated Output
SELECT
    '"' + @PKEY + '"' AS PKEY,
    '"' + CONVERT(NVARCHAR(MAX), database_name) + '"' AS database_name,
    '"' + CONVERT(NVARCHAR(MAX), schema_name) + '"' AS schema_name,
    '"' + CONVERT(NVARCHAR(MAX), object_name) + '"' AS object_name,
    '"' + CONVERT(NVARCHAR(MAX), object_type) + '"' AS object_type,
    '"' + CONVERT(NVARCHAR(MAX), incompatibility_type) + '"' AS incompatibility_type,
    '"' + CONVERT(NVARCHAR(MAX), severity) + '"' AS severity,
    '"' + CONVERT(NVARCHAR(MAX), CASE WHEN incompatibility_type = 'NONE_DETECTED' THEN 0 ELSE COUNT(*) END) + '"' AS violation_count,
    '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
    '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id
FROM #DetectedBlockers
GROUP BY database_name, schema_name, object_name, object_type, incompatibility_type, severity
ORDER BY severity DESC, database_name ASC, object_name ASC;

IF OBJECT_ID('tempdb..#BlockerPatterns') IS NOT NULL
    DROP TABLE #BlockerPatterns;

IF OBJECT_ID('tempdb..#DetectedBlockers') IS NOT NULL
    DROP TABLE #DetectedBlockers;
