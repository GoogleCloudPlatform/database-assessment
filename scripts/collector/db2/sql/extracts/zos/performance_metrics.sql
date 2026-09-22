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

WITH rts AS (
    SELECT
        COUNT(DISTINCT DBNAME) AS active_db_count,
        COALESCE(SUM(CAST(SPACE AS BIGINT)), 0) AS total_space_kb,
        COALESCE(SUM(CAST(NACTIVE AS BIGINT)), 0) AS total_active_pages,
        COALESCE(SUM(CAST(TOTALROWS AS BIGINT)), 0) AS total_rows,
        COALESCE(SUM(CAST(REORGSELECTS AS BIGINT)), 0) AS total_selects,
        COALESCE(SUM(CAST(REORGINSERTS AS BIGINT)), 0) AS total_inserts,
        COALESCE(SUM(CAST(REORGUPDATES AS BIGINT)), 0) AS total_updates,
        COALESCE(SUM(CAST(REORGDELETES AS BIGINT)), 0) AS total_deletes
    FROM SYSIBM.SYSTABLESPACESTATS
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    '1' || '|' ||
    CHR(34) || VARCHAR(CHAR(CURRENT TIMESTAMP)) || CHR(34) || '|' ||
    '3600' || '|' ||
    '0.00' || '|' ||
    VARCHAR(COALESCE(r.active_db_count, 1)) || '|' ||
    '1' || '|' ||
    VARCHAR(COALESCE(r.total_selects, 0)) || '|' ||
    VARCHAR(COALESCE(r.total_inserts + r.total_updates + r.total_deletes, 0)) || '|' ||
    VARCHAR(CAST(ROUND((COALESCE(r.total_space_kb, 0) / 1024.0) / 1024.0, 2) AS DECIMAL(18, 2))) || '|' ||
    '0.00' || '|' ||
    VARCHAR(COALESCE(r.total_active_pages, 0)) || '|' ||
    VARCHAR(COALESCE(r.total_inserts + r.total_updates + r.total_deletes, 0)) || '|' ||
    VARCHAR(COALESCE(r.total_selects + r.total_inserts + r.total_updates + r.total_deletes, 0)) || '|' ||
    '0' || '|' ||
    '100.00'
FROM SYSIBM.SYSDUMMY1
LEFT JOIN rts r ON 1=1;
