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
        TABSCHEMA,
        TABNAME,
        SUM(CASE WHEN TYPENAME IN ('CHARACTER', 'CHAR', 'GRAPHIC') THEN 1 ELSE 0 END) AS CHAR_COL_COUNT,
        SUM(CASE WHEN TYPENAME IN ('VARCHAR', 'VARGRAPHIC', 'LONG VARCHAR') THEN 1 ELSE 0 END) AS VARCHAR_COL_COUNT,
        SUM(CASE WHEN TYPENAME IN ('INTEGER', 'BIGINT', 'SMALLINT', 'DECIMAL', 'NUMERIC', 'DECFLOAT') THEN 1 ELSE 0 END) AS NUMBER_COL_COUNT,
        SUM(CASE WHEN TYPENAME IN ('DATE', 'TIME') THEN 1 ELSE 0 END) AS DATE_COL_COUNT,
        SUM(CASE WHEN TYPENAME = 'TIMESTAMP' THEN 1 ELSE 0 END) AS TIMESTAMP_COL_COUNT,
        SUM(CASE WHEN TYPENAME IN ('FLOAT', 'REAL', 'DOUBLE') THEN 1 ELSE 0 END) AS FLOAT_COL_COUNT,
        SUM(CASE WHEN TYPENAME IN ('BLOB', 'BINARY', 'VARBINARY') THEN 1 ELSE 0 END) AS BLOB_COL_COUNT,
        SUM(CASE WHEN TYPENAME IN ('CLOB', 'DBCLOB') THEN 1 ELSE 0 END) AS CLOB_COL_COUNT,
        SUM(CASE WHEN TYPENAME = 'XML' THEN 1 ELSE 0 END) AS XML_COL_COUNT,
        SUM(CASE WHEN TYPENAME LIKE 'ST_%' OR TYPENAME = 'DB2GSE' THEN 1 ELSE 0 END) AS SPATIAL_COL_COUNT,
        SUM(CASE WHEN TYPESCHEMA NOT IN ('SYSIBM', 'SYSFUN') THEN 1 ELSE 0 END) AS USER_DEFINED_COL_COUNT,
        SUM(CASE WHEN NULLS = 'N' THEN 1 ELSE 0 END) AS NOT_NULL_CONS_COUNT
    FROM SYSCAT.COLUMNS
    WHERE TABSCHEMA NOT LIKE 'SYS%' AND TABSCHEMA NOT IN ('NULLID', 'SQLJ', 'DB2GSE')
    GROUP BY TABSCHEMA, TABNAME
),
cons_counts AS (
    SELECT
        TABSCHEMA,
        TABNAME,
        SUM(CASE WHEN TYPE = 'P' THEN 1 ELSE 0 END) AS PRIMARY_KEY_COUNT,
        SUM(CASE WHEN TYPE = 'U' THEN 1 ELSE 0 END) AS UNIQUE_CONS_COUNT,
        SUM(CASE WHEN TYPE = 'K' THEN 1 ELSE 0 END) AS CHECK_CONS_COUNT,
        SUM(CASE WHEN TYPE = 'F' THEN 1 ELSE 0 END) AS FOREIGN_KEY_CONS_COUNT
    FROM SYSCAT.TABCONST
    WHERE TABSCHEMA NOT LIKE 'SYS%' AND TABSCHEMA NOT IN ('NULLID', 'SQLJ')
    GROUP BY TABSCHEMA, TABNAME
),
part_counts AS (
    SELECT
        TABSCHEMA,
        TABNAME,
        COUNT(1) AS PARTITION_COUNT
    FROM SYSCAT.DATAPARTITIONS
    GROUP BY TABSCHEMA, TABNAME
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(t.TABSCHEMA)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(t.TABNAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE 
        WHEN t.TYPE = 'T' THEN 'TABLE'
        WHEN t.TYPE = 'V' THEN 'VIEW'
        WHEN t.TYPE = 'S' THEN 'MQT'
        WHEN t.TYPE = 'A' THEN 'ALIAS'
        WHEN t.TYPE = 'H' THEN 'HIERARCHY_TABLE'
        WHEN t.TYPE = 'N' THEN 'NICKNAME'
        ELSE 'OTHER_TABLE'
    END) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(COALESCE(t.STATUS, 'N/A')), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN COALESCE(p.PARTITION_COUNT, 0) > 1 OR (t.PMAP_ID IS NOT NULL AND t.PMAP_ID >= 0) THEN 'Y' ELSE 'N' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE 
        WHEN COALESCE(p.PARTITION_COUNT, 0) > 1 AND (t.PMAP_ID IS NOT NULL AND t.PMAP_ID >= 0) THEN 'COMPOSITE_RANGE_HASH'
        WHEN COALESCE(p.PARTITION_COUNT, 0) > 1 THEN 'RANGE'
        WHEN t.PMAP_ID IS NOT NULL AND t.PMAP_ID >= 0 THEN 'DB2_DPF_HASH'
        ELSE 'NONE'
    END) || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    VARCHAR(COALESCE(p.PARTITION_COUNT, 0)) || '|' ||
    '0' || '|' ||
    CHR(34) || VARCHAR(CASE WHEN t.TYPE = 'G' OR t.PROPERTY LIKE '%T%' THEN 'Y' ELSE 'N' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN t.PROPERTY LIKE '%E%' THEN 'Y' ELSE 'N' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE 
        WHEN t.PROPERTY LIKE '%C%' THEN 'COLUMNAR'
        WHEN t.COMPRESSION IN ('R', 'B', 'V') THEN 'ROW'
        ELSE 'NONE'
    END) || CHR(34) || '|' ||
    VARCHAR(CAST(ROUND((COALESCE(t.FPAGES, t.NPAGES, 0) * 4.0) / 1024.0, 2) AS DECIMAL(18, 2))) || '|' ||
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
    VARCHAR(COALESCE(k.CHECK_CONS_COUNT, 0)) || '|' ||
    VARCHAR(COALESCE(k.FOREIGN_KEY_CONS_COUNT, 0)) || '|' ||
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
FROM SYSCAT.TABLES t
LEFT JOIN col_counts c ON t.TABSCHEMA = c.TABSCHEMA AND t.TABNAME = c.TABNAME
LEFT JOIN cons_counts k ON t.TABSCHEMA = k.TABSCHEMA AND t.TABNAME = k.TABNAME
LEFT JOIN part_counts p ON t.TABSCHEMA = p.TABSCHEMA AND t.TABNAME = p.TABNAME
WHERE t.TABSCHEMA NOT LIKE 'SYS%' AND t.TABSCHEMA NOT IN ('NULLID', 'SQLJ', 'DB2GSE')
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.INDSCHEMA)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.INDNAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'INDEX' || CHR(34) || '|' ||
    CHR(34) || 'VALID' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    CHR(34) || 'NONE' || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(COALESCE(i.COMPRESSION, 'N')), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
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
    CHR(34) || VARCHAR(CASE WHEN i.UNIQUERULE IN ('U', 'P') THEN 'UNIQUE' ELSE 'NONUNIQUE' END) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(COALESCE(i.COMPRESSION, 'N')), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'N' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(i.TABNAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    '0' || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34)
FROM SYSCAT.INDEXES i
WHERE i.INDSCHEMA NOT LIKE 'SYS%' AND i.INDSCHEMA NOT IN ('NULLID', 'SQLJ')
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(r.ROUTINESCHEMA)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(r.ROUTINENAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(r.ROUTINETYPE)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(COALESCE(r.VALID, 'Y')), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
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
    VARCHAR(CASE WHEN r.TEXT IS NOT NULL THEN (LENGTH(r.TEXT) - LENGTH(REPLACE(r.TEXT, CHR(10), '')) + 1) ELSE 1 END) || '|' ||
    VARCHAR(CASE WHEN r.TEXT LIKE '%UTL_FILE%' OR r.TEXT LIKE '%UTL_HTTP%' THEN 1 ELSE 0 END) || '|' ||
    VARCHAR(CASE WHEN r.TEXT LIKE '%EXECUTE IMMEDIATE%' OR r.TEXT LIKE '%PREPARE%' THEN 1 ELSE 0 END) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34)
FROM SYSCAT.ROUTINES r
WHERE r.ROUTINESCHEMA NOT LIKE 'SYS%' AND r.ROUTINESCHEMA NOT IN ('NULLID', 'SQLJ', 'DB2GSE')
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(tr.TRIGSCHEMA)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(tr.TRIGNAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'TRIGGER' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(COALESCE(tr.VALID, 'Y')), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
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
    CHR(34) || REPLACE(VARCHAR(RTRIM(tr.TABNAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    VARCHAR(CASE WHEN tr.TEXT IS NOT NULL THEN (LENGTH(tr.TEXT) - LENGTH(REPLACE(tr.TEXT, CHR(10), '')) + 1) ELSE 1 END) || '|' ||
    VARCHAR(CASE WHEN tr.TEXT LIKE '%UTL_FILE%' OR tr.TEXT LIKE '%UTL_HTTP%' THEN 1 ELSE 0 END) || '|' ||
    VARCHAR(CASE WHEN tr.TEXT LIKE '%EXECUTE IMMEDIATE%' THEN 1 ELSE 0 END) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(tr.TRIGTIME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(tr.TRIGEVENT)), CHR(34), CHR(92) || CHR(34)) || CHR(34)
FROM SYSCAT.TRIGGERS tr
WHERE tr.TRIGSCHEMA NOT LIKE 'SYS%' AND tr.TRIGSCHEMA NOT IN ('NULLID', 'SQLJ');
