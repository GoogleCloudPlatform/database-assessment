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

WITH f_columnar AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.TABLES WHERE PROPERTY LIKE '%C%'
),
f_range_part AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.DATAPARTITIONS
),
f_temporal AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.TABLES WHERE TEMPORALTYPE IN ('S', 'B')
),
f_mqt AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.TABLES WHERE TYPE = 'S'
),
f_federated AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.TABLES WHERE TYPE = 'N'
),
f_external_routines AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.ROUTINES WHERE LANGUAGE IN ('C', 'JAVA', 'OLE', 'CLR')
),
f_rcac AS (
    SELECT COUNT(1) AS cnt FROM SYSCAT.CONTROLS
),
f_hadr AS (
    SELECT COUNT(1) AS cnt
    FROM SYSIBMADM.DBCFG
    WHERE NAME = 'hadr_role' AND VALUE IS NOT NULL AND VALUE NOT IN ('', 'OFF', 'STANDARD')
),
f_encr AS (
    SELECT COUNT(1) AS cnt
    FROM SYSIBMADM.DBCFG
    WHERE NAME = 'encropt' AND VALUE IS NOT NULL AND VALUE != ''
)
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STORAGE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'BLU Acceleration (Columnar Tables)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'DB2 columnar BLU tables' || CHR(34)
FROM f_columnar
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'STORAGE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Table Partitioning (DPF / Range)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Data partition count' || CHR(34)
FROM f_range_part
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'ENTERPRISE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Temporal Tables (Time Travel)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'System-period or application-period temporal tables' || CHR(34)
FROM f_temporal
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'ENTERPRISE_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Materialized Query Tables (MQT)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Summary tables and materialized query views' || CHR(34)
FROM f_mqt
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'SYNTAX_BLOCKER' || CHR(34) || '|' ||
    CHR(34) || 'Federated Nicknames (Remote Objects)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Federated wrapper nicknames pointing to remote databases' || CHR(34)
FROM f_federated
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'SYNTAX_BLOCKER' || CHR(34) || '|' ||
    CHR(34) || 'External C/Java Stored Routines' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'Routines written in C, Java, OLE, or CLR' || CHR(34)
FROM f_external_routines
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
    CHR(34) || 'Row permission or column mask policies' || CHR(34)
FROM f_rcac
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'HA_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'High Availability Disaster Recovery (HADR)' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'HADR standby replication configuration' || CHR(34)
FROM f_hadr
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'SECURITY_FEATURE' || CHR(34) || '|' ||
    CHR(34) || 'Native Database Encryption' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN cnt > 0 THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    VARCHAR(cnt) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'N/A' || CHR(34) || '|' ||
    CHR(34) || 'DB2 native encryption key manager option' || CHR(34)
FROM f_encr;
