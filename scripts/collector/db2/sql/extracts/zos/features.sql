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

WITH f_data_sharing AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSDUMMY1
),
f_partitioned_ts AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTABLESPACE WHERE TYPE IN ('R', 'G') OR MAXPARTITIONS > 0
),
f_compression AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTABLESPACE WHERE COMPRESS IN ('Y', 'F')
),
f_temporal AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTABLES WHERE TEMPORALTYPE IN ('S', 'B')
),
f_mqt AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTABLES WHERE TYPE = 'M'
),
f_aux_tables AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTABLES WHERE TYPE = 'X'
),
f_rcac AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTABLES WHERE CONTROL IN ('R', 'C', 'B')
),
f_external_routines AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSROUTINES WHERE LANGUAGE IN ('C', 'JAVA', 'COBOL', 'PLI')
),
f_triggers AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSTRIGGERS WHERE SCHEMA NOT LIKE 'SYS%'
),
f_xml AS (
    SELECT COUNT(1) AS cnt FROM SYSIBM.SYSCOLUMNS WHERE COLTYPE = 'XML'
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'HA_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Data Sharing Parallel Sysplex' || CHR(34) || '|' ||
    CHR(34) || 'TRUE' || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'z/OS Parallel Sysplex data sharing group' || CHR(34)
FROM f_data_sharing
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STORAGE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Partitioned Table Spaces (PBR/PBG)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Partition-by-range or partition-by-growth table spaces' || CHR(34)
FROM f_partitioned_ts
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STORAGE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Table Space Data Compression' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Hardware or fixed-length compressed table spaces' || CHR(34)
FROM f_compression
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'ENGINE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Temporal Tables (System/Application Period)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Temporal versioning tables' || CHR(34)
FROM f_temporal
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'PERFORMANCE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Materialized Query Tables (MQT)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Materialized query tables' || CHR(34)
FROM f_mqt
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STORAGE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Auxiliary Tables (LOB Storage)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Auxiliary tables storing out-of-line LOB data' || CHR(34)
FROM f_aux_tables
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'SECURITY_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Row and Column Access Control (RCAC)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Tables with Row or Column level access control' || CHR(34)
FROM f_rcac
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'PROGRAMMABILITY_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'External Language Routines' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Routines written in C, Java, COBOL, or PL/I' || CHR(34)
FROM f_external_routines
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'PROGRAMMABILITY_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Database Triggers' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Active user-defined database triggers' || CHR(34)
FROM f_triggers
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STORAGE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'XML Column Datatypes' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Columns utilizing the pureXML data type' || CHR(34)
FROM f_xml;
