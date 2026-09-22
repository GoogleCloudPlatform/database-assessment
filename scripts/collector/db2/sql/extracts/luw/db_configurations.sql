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

SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(i.INST_NAME, 'DEFAULT'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'INSTANCE' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(c.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.VALUE, 'N/A'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.VALUE_FLAGS, 'N/A'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN c.VALUE_FLAGS LIKE '%DEFAULT%' THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN c.DEFERRED_VALUE = c.VALUE THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || 'Database Manager Configuration (DBMCFG)' || CHR(34)
FROM SYSIBMADM.DBMCFG c,
     TABLE(SYSPROC.ENV_GET_INST_INFO()) i
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(i.INST_NAME, 'DEFAULT'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(c.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.VALUE, 'N/A'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(COALESCE(c.VALUE_FLAGS, 'N/A'))), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN c.VALUE_FLAGS LIKE '%DEFAULT%' THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN c.DEFERRED_VALUE = c.VALUE THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || 'Database Configuration (DBCFG)' || CHR(34)
FROM SYSIBMADM.DBCFG c,
     TABLE(SYSPROC.ENV_GET_INST_INFO()) i;
