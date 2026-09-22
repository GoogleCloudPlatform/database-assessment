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

WITH bp_hit AS (
    SELECT
        CAST(
            ROUND(
                CASE 
                    WHEN (SUM(POOL_DATA_L_READS + POOL_INDEX_L_READS)) = 0 THEN 100.00
                    ELSE 100.00 * (1.0 - (DOUBLE(SUM(POOL_DATA_P_READS + POOL_INDEX_P_READS)) / 
                                          DOUBLE(SUM(POOL_DATA_L_READS + POOL_INDEX_L_READS))))
                END, 2
            ) AS DECIMAL(5, 2)
        ) AS buffer_cache_hit_ratio
    FROM TABLE(SYSPROC.MON_GET_BUFFERPOOL(NULL, -2))
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM((SELECT COALESCE(INST_NAME, 'DEFAULT') FROM TABLE(SYSPROC.ENV_GET_INST_INFO())))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    '1' || '|' ||
    CHR(34) || VARCHAR(CHAR(CURRENT TIMESTAMP)) || CHR(34) || '|' ||
    '3600' || '|' ||
    '0.00' || '|' ||
    VARCHAR(CAST(COALESCE(m.TOTAL_APP_COMMITS + m.TOTAL_APP_ROLLBACKS, 0) AS BIGINT)) || '|' ||
    VARCHAR(CAST(COALESCE(m.APPLS_IN_DB2, 0) AS BIGINT)) || '|' ||
    VARCHAR(CAST(COALESCE(m.POOL_DATA_P_READS + m.POOL_INDEX_P_READS, 0) AS BIGINT)) || '|' ||
    VARCHAR(CAST(COALESCE(m.POOL_DATA_WRITES + m.POOL_INDEX_WRITES, 0) AS BIGINT)) || '|' ||
    VARCHAR(CAST(ROUND(COALESCE(m.POOL_READ_TIME, 0) / 1024.0, 2) AS DECIMAL(18, 2))) || '|' ||
    VARCHAR(CAST(ROUND(COALESCE(m.POOL_WRITE_TIME, 0) / 1024.0, 2) AS DECIMAL(18, 2))) || '|' ||
    VARCHAR(CAST(COALESCE(m.POOL_DATA_L_READS + m.POOL_INDEX_L_READS, 0) AS BIGINT)) || '|' ||
    VARCHAR(CAST(COALESCE(m.TOTAL_APP_COMMITS, 0) AS BIGINT)) || '|' ||
    VARCHAR(CAST(COALESCE(m.ROWS_READ + m.ROWS_MODIFIED, 0) AS BIGINT)) || '|' ||
    '0' || '|' ||
    VARCHAR(COALESCE(b.buffer_cache_hit_ratio, 100.00))
FROM TABLE(SYSPROC.MON_GET_DATABASE(-2)) m,
     bp_hit b;
