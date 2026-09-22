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

WITH col_counts AS (
    SELECT
        TBCREATOR,
        TBNAME,
        SUM(CASE WHEN COLTYPE IN ('CHAR', 'GRAPHIC') THEN 1 ELSE 0 END) AS CHAR_COL_COUNT,
        SUM(CASE WHEN COLTYPE IN ('VARCHAR', 'VARG') THEN 1 ELSE 0 END) AS VARCHAR_COL_COUNT,
        SUM(CASE WHEN COLTYPE IN ('INTEGER', 'SMALLINT', 'BIGINT', 'DECIMAL') THEN 1 ELSE 0 END) AS NUMBER_COL_COUNT,
        SUM(CASE WHEN COLTYPE IN ('DATE', 'TIME') THEN 1 ELSE 0 END) AS DATE_COL_COUNT,
        SUM(CASE WHEN COLTYPE LIKE 'TIMEST%' THEN 1 ELSE 0 END) AS TIMESTAMP_COL_COUNT,
        SUM(CASE WHEN COLTYPE IN ('FLOAT', 'DECFLOAT') THEN 1 ELSE 0 END) AS FLOAT_COL_COUNT,
        SUM(CASE WHEN COLTYPE = 'BLOB' THEN 1 ELSE 0 END) AS BLOB_COL_COUNT,
        SUM(CASE WHEN COLTYPE IN ('CLOB', 'DBCLOB') THEN 1 ELSE 0 END) AS CLOB_COL_COUNT,
        SUM(CASE WHEN COLTYPE = 'XML' THEN 1 ELSE 0 END) AS XML_COL_COUNT,
        0 AS SPATIAL_COL_COUNT,
        0 AS USER_DEFINED_COL_COUNT,
        SUM(CASE WHEN NULLS = 'N' THEN 1 ELSE 0 END) AS NOT_NULL_CONS_COUNT
    FROM SYSIBM.SYSCOLUMNS
    GROUP BY TBCREATOR, TBNAME
),
idx_cons AS (
    SELECT
        TBCREATOR,
        TBNAME,
        SUM(CASE WHEN UNIQUERULE = 'P' THEN 1 ELSE 0 END) AS PRIMARY_KEY_COUNT,
        SUM(CASE WHEN UNIQUERULE = 'U' THEN 1 ELSE 0 END) AS UNIQUE_CONS_COUNT
    FROM SYSIBM.SYSINDEXES
    GROUP BY TBCREATOR, TBNAME
),
fk_cons AS (
    SELECT
        CREATOR,
        TBNAME,
        COUNT(1) AS FOREIGN_KEY_CONS_COUNT
    FROM SYSIBM.SYSRELS
    GROUP BY CREATOR, TBNAME
),
chk_cons AS (
    SELECT
        TBCREATOR,
        TBNAME,
        COUNT(1) AS CHECK_CONS_COUNT
    FROM SYSIBM.SYSCHECKS
    GROUP BY TBCREATOR, TBNAME
),
part_counts AS (
    SELECT
        DBNAME,
        TSNAME,
        COUNT(1) AS PARTITION_COUNT
    FROM SYSIBM.SYSTABLEPART
    GROUP BY DBNAME, TSNAME
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(t.CREATOR)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(t.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE t.TYPE 
        WHEN 'T' THEN 'TABLE'
        WHEN 'V' THEN 'VIEW'
        WHEN 'M' THEN 'MQT'
        WHEN 'A' THEN 'ALIAS'
        WHEN 'G' THEN 'GLOBAL_TEMPORARY'
        WHEN 'H' THEN 'CREATED_TEMPORARY'
        WHEN 'X' THEN 'AUXILIARY_TABLE'
        WHEN 'P' THEN 'CLONE_TABLE'
        ELSE 'OTHER_TABLE'
    END) || CHR(34) || '|' ||
    CHR(34) || 'VALID' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN t.PARTITIONED = 'Y' OR COALESCE(p.PARTITION_COUNT, 0) > 1 THEN 'Y' ELSE 'N' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN t.PARTITIONED = 'Y' OR COALESCE(p.PARTITION_COUNT, 0) > 1 THEN 'RANGE' ELSE 'NONE' END) || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    VARCHAR(COALESCE(p.PARTITION_COUNT, 0)) || '|' ||
    '0' || '|' ||
    CHR(34) || VARCHAR(CASE WHEN t.TYPE IN ('G', 'H') THEN 'Y' ELSE 'N' END) || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    VARCHAR(CAST(ROUND((COALESCE(t.NPAGES, 0) * 4.0) / 1024.0, 2) AS DECIMAL(18, 2))) || '|' ||
    VARCHAR(COALESCE(c.CHAR_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.VARCHAR_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.NUMBER_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.DATE_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.TIMESTAMP_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.FLOAT_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.BLOB_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.CLOB_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.XML_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.SPATIAL_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.USER_DEFINED_COL_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(k.PRIMARY_KEY_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(k.UNIQUE_CONS_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(chk.CHECK_CONS_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(fk.FOREIGN_KEY_CONS_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(c.NOT_NULL_CONS_COUNT, 0)) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34)
FROM SYSIBM.SYSTABLES t
LEFT JOIN col_counts c ON t.CREATOR = c.TBCREATOR AND t.NAME = c.TBNAME
LEFT JOIN idx_cons k ON t.CREATOR = k.TBCREATOR AND t.NAME = k.TBNAME
LEFT JOIN fk_cons fk ON t.CREATOR = fk.CREATOR AND t.NAME = fk.TBNAME
LEFT JOIN chk_cons chk ON t.CREATOR = chk.TBCREATOR AND t.NAME = chk.TBNAME
LEFT JOIN part_counts p ON t.DBNAME = p.DBNAME AND t.TSNAME = p.TSNAME
WHERE t.CREATOR NOT LIKE 'SYS%' AND t.CREATOR NOT IN ('NULLID', 'SQLJ')
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.CREATOR)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'INDEX' || CHR(34) || '|' ||
    CHR(34) || 'VALID' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0.00' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.INDEXTYPE)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN i.UNIQUERULE IN ('U', 'P') THEN 'UNIQUE' ELSE 'NON_UNIQUE' END) || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN i.CLUSTERING = 'Y' THEN 'Y' ELSE 'N' END) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.TBNAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34)
FROM SYSIBM.SYSINDEXES i
WHERE i.CREATOR NOT LIKE 'SYS%'
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(r.SCHEMA)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(r.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN r.ROUTINETYPE = 'P' THEN 'PROCEDURE' ELSE 'FUNCTION' END) || CHR(34) || '|' ||
    CHR(34) || 'VALID' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0.00' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    VARCHAR(CAST(ROUND(COALESCE(LENGTH(r.TEXT), 0) / 40.0, 0) AS BIGINT)) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34)
FROM SYSIBM.SYSROUTINES r
WHERE r.SCHEMA NOT LIKE 'SYS%'
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(tg.SCHEMA)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(tg.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'TRIGGER' || CHR(34) || '|' ||
    CHR(34) || 'VALID' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0.00' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    VARCHAR(CAST(ROUND(COALESCE(LENGTH(tg.TEXT), 0) / 40.0, 0) AS BIGINT)) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || VARCHAR(CASE tg.TRIGTIME WHEN 'B' THEN 'BEFORE' WHEN 'A' THEN 'AFTER' WHEN 'I' THEN 'INSTEAD_OF' ELSE 'UNKNOWN' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE tg.TRIGEVENT WHEN 'I' THEN 'INSERT' WHEN 'U' THEN 'UPDATE' WHEN 'D' THEN 'DELETE' ELSE 'UNKNOWN' END) || CHR(34)
FROM SYSIBM.SYSTRIGGERS tg
WHERE tg.SCHEMA NOT LIKE 'SYS%';
