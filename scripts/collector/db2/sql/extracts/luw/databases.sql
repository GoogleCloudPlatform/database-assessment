-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.

WITH t_size AS (
    SELECT
        CAST(ROUND(COALESCE(SUM(DOUBLE(TBSP_TOTAL_PAGES) * DOUBLE(TBSP_PAGE_SIZE)), 0) / (1024.0 * 1024.0 * 1024.0), 3) AS DECIMAL(18, 3)) AS total_alloc_gb,
        CAST(ROUND(COALESCE(SUM(DOUBLE(TBSP_USED_PAGES) * DOUBLE(TBSP_PAGE_SIZE)), 0) / (1024.0 * 1024.0 * 1024.0), 3) AS DECIMAL(18, 3)) AS total_used_gb,
        CAST(ROUND(COALESCE(SUM(CASE WHEN TBSP_CONTENT_TYPE LIKE '%TEMP%' THEN DOUBLE(TBSP_TOTAL_PAGES) * DOUBLE(TBSP_PAGE_SIZE) ELSE 0 END), 0) / (1024.0 * 1024.0 * 1024.0), 3) AS DECIMAL(18, 3)) AS temp_alloc_gb
    FROM TABLE(SYSPROC.MON_GET_TABLESPACE(NULL, -2))
),
t_cfg AS (
    SELECT
        (SELECT VALUE FROM SYSIBMADM.DBCFG WHERE NAME = 'logarchmeth1') AS log_mode,
        (SELECT VALUE FROM SYSIBMADM.DBCFG WHERE NAME = 'codepage') AS codepage,
        (SELECT VALUE FROM SYSIBMADM.DBCFG WHERE NAME = 'collate_info') AS collate_info,
        (SELECT VALUE FROM SYSIBMADM.DBCFG WHERE NAME = 'hadr_role') AS hadr_role
    FROM SYSIBM.SYSDUMMY1
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STANDALONE' || CHR(34) || '|' ||
    CHR(34) || 'READ_WRITE' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.codepage, 'UTF-8'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.collate_info, 'IDENTITY'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN c.log_mode = 'OFF' THEN 'NOARCHIVELOG' ELSE 'ARCHIVELOG' END) || CHR(34) || '|' ||
    CHR(34) || 'NO' || CHR(34) || '|' ||
    VARCHAR(s.total_alloc_gb) || '|' ||
    VARCHAR(s.total_used_gb) || '|' ||
    VARCHAR(s.temp_alloc_gb) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.hadr_role, 'STANDARD'))), CHR(34), CHR(92) || CHR(34)) || CHR(34)
FROM SYSIBM.SYSDUMMY1 d,
     t_size s,
     t_cfg c;
