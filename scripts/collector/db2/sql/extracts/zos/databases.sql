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

WITH db_storage AS (
    SELECT
        DBNAME,
        COALESCE(SUM(SPACE), 0) AS total_alloc_kb,
        COALESCE(SUM(CAST(NACTIVE AS BIGINT) * CAST(PGSIZE AS BIGINT)), 0) AS total_used_kb
    FROM SYSIBM.SYSTABLESPACE
    GROUP BY DBNAME
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE d.TYPE WHEN 'W' THEN 'WORKFILE' WHEN 'T' THEN 'TEMP' ELSE 'STANDARD' END) || CHR(34) || '|' ||
    CHR(34) || 'READ_WRITE' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE d.ENCODING_SCHEME WHEN 'E' THEN 'EBCDIC' WHEN 'A' THEN 'ASCII' WHEN 'U' THEN 'UNICODE' ELSE 'EBCDIC' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE d.ENCODING_SCHEME WHEN 'E' THEN 'EBCDIC' WHEN 'A' THEN 'ASCII' WHEN 'U' THEN 'UNICODE' ELSE 'EBCDIC' END) || CHR(34) || '|' ||
    CHR(34) || 'ARCHIVELOG' || CHR(34) || '|' ||
    CHR(34) || 'NO' || CHR(34) || '|' ||
    VARCHAR(CAST(ROUND(COALESCE(s.total_alloc_kb, 0) / (1024.0 * 1024.0), 3) AS DECIMAL(18, 3))) || '|' ||
    VARCHAR(CAST(ROUND(COALESCE(s.total_used_kb, 0) / (1024.0 * 1024.0), 3) AS DECIMAL(18, 3))) || '|' ||
    VARCHAR(CAST(ROUND(CASE WHEN d.TYPE = 'W' OR d.NAME = 'DSNDB07' THEN COALESCE(s.total_alloc_kb, 0) / (1024.0 * 1024.0) ELSE 0.000 END, 3) AS DECIMAL(18, 3))) || '|' ||
    CHR(34) || 'DATA_SHARING' || CHR(34)
FROM SYSIBM.SYSDATABASE d
LEFT JOIN db_storage s ON d.NAME = s.DBNAME;
