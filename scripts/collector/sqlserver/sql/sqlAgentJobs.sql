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

IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'msdb' AND HAS_DBACCESS('msdb') = 1)
   AND OBJECT_ID('msdb.dbo.sysjobs') IS NOT NULL
   AND OBJECT_ID('msdb.dbo.sysjobsteps') IS NOT NULL
   AND OBJECT_ID('msdb.dbo.syscategories') IS NOT NULL
   AND HAS_PERMS_BY_NAME('msdb.dbo.sysjobs', 'OBJECT', 'SELECT') = 1
   AND HAS_PERMS_BY_NAME('msdb.dbo.sysjobsteps', 'OBJECT', 'SELECT') = 1
   AND HAS_PERMS_BY_NAME('msdb.dbo.syscategories', 'OBJECT', 'SELECT') = 1
BEGIN
    SELECT
        '"' + @PKEY + '"' AS pkey,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id,
        '"' + CONVERT(NVARCHAR(MAX), j.job_id) + '"' AS job_id,
        '"' + REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(j.name, N'')), '"', '""') + '"' AS job_name,
        '"' + CONVERT(NVARCHAR(MAX), j.enabled) + '"' AS job_enabled,
        '"' + REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(c.name, N'')), '"', '""') + '"' AS category_name,
        '"' + REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(j.description, N'')), '"', '""'), CHAR(13), ' '), CHAR(10), ' ') + '"' AS job_description,
        '"' + CONVERT(NVARCHAR(MAX), s.step_id) + '"' AS step_id,
        '"' + REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(s.step_name, N'')), '"', '""'), CHAR(13), ' '), CHAR(10), ' ') + '"' AS step_name,
        '"' + REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(s.subsystem, N'')), '"', '""') + '"' AS subsystem,
        '"' + REPLACE(REPLACE(REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(s.command, N'')), '"', '""'), CHAR(13), ' '), CHAR(10), ' ') + '"' AS command,
        '"' + REPLACE(CONVERT(NVARCHAR(MAX), ISNULL(s.database_name, N'')), '"', '""') + '"' AS database_name,
        '"' + CASE
            -- 1. Non-T-SQL Subsystems
            WHEN UPPER(s.subsystem) IN ('CMDEXEC', 'POWERSHELL', 'SSIS', 'PACKAGE', 'ACTIVESCRIPTING', 'ANALYSISQUERY', 'ANALYSISCOMMAND', 'DISTRIBUTION', 'MERGE', 'QUEUEREADER', 'LOGREADER', 'SNAPSHOT')
                THEN 'NON_TSQL_SUBSYSTEM'
            -- 2. OS & External Integrations
            WHEN s.command LIKE '%xp_cmdshell%' OR s.command LIKE '%xp_sendmail%' OR s.command LIKE '%xp_dirtree%' OR s.command LIKE '%xp_fileexist%' OR s.command LIKE '%xp_regread%' OR s.command LIKE '%xp_regwrite%'
                 OR s.command LIKE '%sp_OACreate%' OR s.command LIKE '%sp_OAMethod%' OR s.command LIKE '%sp_OASetProperty%'
                 OR s.command LIKE '%sp_send_dbmail%' OR s.command LIKE '%sp_notify_operator%'
                 OR s.command LIKE '%OPENQUERY%' OR s.command LIKE '%OPENROWSET%'
                THEN 'OS_EXTERNAL_INTEGRATION'
            -- 3. Proprietary Maintenance Commands
            WHEN s.command LIKE '%BACKUP DATABASE%' OR s.command LIKE '%BACKUP LOG%' OR s.command LIKE '%RESTORE DATABASE%' OR s.command LIKE '%RESTORE LOG%'
                 OR s.command LIKE '%DBCC CHECKDB%' OR s.command LIKE '%DBCC SHRINKDATABASE%' OR s.command LIKE '%DBCC SHRINKFILE%' OR s.command LIKE '%DBCC FREEPROCCACHE%'
                 OR s.command LIKE '%REBUILD%' OR s.command LIKE '%REORGANIZE%' OR s.command LIKE '%sp_updatestats%' OR s.command LIKE '%UPDATE STATISTICS%'
                THEN 'MAINTENANCE_COMMAND'
            -- 4. Macro Tokens
            WHEN s.command LIKE '%$' + '(ESCAPE_%' OR s.command LIKE '%$' + '(JOBNAME)%' OR s.command LIKE '%$' + '(STEPID)%' OR s.command LIKE '%$' + '(SRVR)%' OR s.command LIKE '%$' + '(DATE)%' OR s.command LIKE '%$' + '(TIME)%' OR s.command LIKE '%$' + '(JOBID)%' OR s.command LIKE '%$' + '(MACH)%'
                THEN 'MACRO_TOKEN'
            ELSE 'NONE'
        END + '"' AS incompatibility_category,
        '"' + CASE
            -- Subsystems
            WHEN UPPER(s.subsystem) = 'CMDEXEC' THEN 'SUBSYSTEM_CMDEXEC'
            WHEN UPPER(s.subsystem) = 'POWERSHELL' THEN 'SUBSYSTEM_POWERSHELL'
            WHEN UPPER(s.subsystem) IN ('SSIS', 'PACKAGE') THEN 'SUBSYSTEM_SSIS'
            WHEN UPPER(s.subsystem) = 'ACTIVESCRIPTING' THEN 'SUBSYSTEM_ACTIVE_SCRIPTING'
            WHEN UPPER(s.subsystem) IN ('ANALYSISQUERY', 'ANALYSISCOMMAND') THEN 'SUBSYSTEM_SSAS'
            WHEN UPPER(s.subsystem) IN ('DISTRIBUTION', 'MERGE', 'QUEUEREADER', 'LOGREADER', 'SNAPSHOT') THEN 'SUBSYSTEM_REPLICATION'
            -- OS & External Calls
            WHEN s.command LIKE '%xp_cmdshell%' THEN 'CMD_XP_CMDSHELL'
            WHEN s.command LIKE '%xp[_]%' THEN 'CMD_XP_EXTENDED'
            WHEN s.command LIKE '%sp[_]OA%' THEN 'CMD_OLE_AUTOMATION'
            WHEN s.command LIKE '%sp_send_dbmail%' OR s.command LIKE '%sp_notify_operator%' THEN 'CMD_DATABASE_MAIL'
            WHEN s.command LIKE '%OPENQUERY%' OR s.command LIKE '%OPENROWSET%' THEN 'CMD_LINKED_SERVER'
            -- Maintenance
            WHEN s.command LIKE '%BACKUP %' OR s.command LIKE '%RESTORE %' THEN 'CMD_BACKUP_RESTORE'
            WHEN s.command LIKE '%DBCC %' THEN 'CMD_DBCC'
            WHEN s.command LIKE '%REBUILD%' OR s.command LIKE '%REORGANIZE%' OR s.command LIKE '%sp_updatestats%' OR s.command LIKE '%UPDATE STATISTICS%' THEN 'CMD_INDEX_STATS_MAINT'
            -- Macro Tokens
            WHEN s.command LIKE '%$' + '(%' THEN 'AGENT_MACRO_TOKEN'
            ELSE 'STANDARD_TSQL'
        END + '"' AS incompatibility_type,
        '"' + CASE
            WHEN UPPER(s.subsystem) IN ('CMDEXEC', 'POWERSHELL', 'SSIS', 'PACKAGE', 'ACTIVESCRIPTING', 'ANALYSISQUERY', 'ANALYSISCOMMAND', 'DISTRIBUTION', 'MERGE', 'QUEUEREADER', 'LOGREADER', 'SNAPSHOT') THEN 'CRITICAL'
            WHEN s.command LIKE '%xp_cmdshell%' OR s.command LIKE '%sp[_]OA%' OR s.command LIKE '%OPENQUERY%' OR s.command LIKE '%OPENROWSET%' THEN 'CRITICAL'
            WHEN s.command LIKE '%xp[_]%' OR s.command LIKE '%sp_send_dbmail%' OR s.command LIKE '%BACKUP %' OR s.command LIKE '%RESTORE %' OR s.command LIKE '%DBCC %' THEN 'HIGH'
            WHEN s.command LIKE '%REBUILD%' OR s.command LIKE '%REORGANIZE%' OR s.command LIKE '%sp_updatestats%' OR s.command LIKE '%UPDATE STATISTICS%' OR s.command LIKE '%$' + '(%' THEN 'MEDIUM'
            ELSE 'NONE'
        END + '"' AS severity
    FROM msdb.dbo.sysjobs j
    INNER JOIN msdb.dbo.sysjobsteps s ON j.job_id = s.job_id
    LEFT JOIN msdb.dbo.syscategories c ON j.category_id = c.category_id
    ORDER BY j.name, s.step_id;
END
ELSE
BEGIN
    SELECT
        '"' + @PKEY + '"' AS pkey,
        '"' + @DMA_SOURCE_ID + '"' AS dma_source_id,
        '"' + @DMA_MANUAL_ID + '"' AS dma_manual_id,
        CAST(NULL AS NVARCHAR(MAX)) AS job_id,
        CAST(NULL AS NVARCHAR(MAX)) AS job_name,
        CAST(NULL AS NVARCHAR(MAX)) AS job_enabled,
        CAST(NULL AS NVARCHAR(MAX)) AS category_name,
        CAST(NULL AS NVARCHAR(MAX)) AS job_description,
        CAST(NULL AS NVARCHAR(MAX)) AS step_id,
        CAST(NULL AS NVARCHAR(MAX)) AS step_name,
        CAST(NULL AS NVARCHAR(MAX)) AS subsystem,
        CAST(NULL AS NVARCHAR(MAX)) AS command,
        CAST(NULL AS NVARCHAR(MAX)) AS database_name,
        CAST(NULL AS NVARCHAR(MAX)) AS incompatibility_category,
        CAST(NULL AS NVARCHAR(MAX)) AS incompatibility_type,
        CAST(NULL AS NVARCHAR(MAX)) AS severity
    WHERE 1=0;
END;
