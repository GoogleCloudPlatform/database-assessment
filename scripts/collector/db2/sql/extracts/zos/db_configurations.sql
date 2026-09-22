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
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'DEFAULT_TABLESPACE_BUFFERPOOL' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.BPOOL)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'BP0' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN d.BPOOL = 'BP0' THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || 'TRUE' || CHR(34) || '|' ||
    CHR(34) || 'Default buffer pool for table spaces in database ' || RTRIM(d.NAME) || CHR(34)
FROM SYSIBM.SYSDATABASE d
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'DEFAULT_INDEX_BUFFERPOOL' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.INDEXBP)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'BP0' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN d.INDEXBP = 'BP0' THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || 'TRUE' || CHR(34) || '|' ||
    CHR(34) || 'Default buffer pool for indexes in database ' || RTRIM(d.NAME) || CHR(34)
FROM SYSIBM.SYSDATABASE d
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'DEFAULT_STORAGE_GROUP' || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.STGROUP)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'SYSDEFLT' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN d.STGROUP = 'SYSDEFLT' THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || 'FALSE' || CHR(34) || '|' ||
    CHR(34) || 'Default storage group in database ' || RTRIM(d.NAME) || CHR(34)
FROM SYSIBM.SYSDATABASE d
UNION ALL
SELECT
    CHR(34) || REPLACE(VARCHAR(RTRIM('@PKEY@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_SOURCE_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM('@DMA_MANUAL_ID@'), 256), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(CURRENT SERVER)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || REPLACE(VARCHAR(RTRIM(d.NAME)), CHR(34), CHR(92) || CHR(34)) || CHR(34) || '|' ||
    CHR(34) || 'ENCODING_SCHEME' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE d.ENCODING_SCHEME WHEN 'E' THEN 'EBCDIC' WHEN 'A' THEN 'ASCII' WHEN 'U' THEN 'UNICODE' ELSE 'EBCDIC' END) || CHR(34) || '|' ||
    CHR(34) || 'EBCDIC' || CHR(34) || '|' ||
    CHR(34) || VARCHAR(CASE WHEN d.ENCODING_SCHEME = 'E' THEN 'TRUE' ELSE 'FALSE' END) || CHR(34) || '|' ||
    CHR(34) || 'FALSE' || CHR(34) || '|' ||
    CHR(34) || 'Encoding scheme for database ' || RTRIM(d.NAME) || CHR(34)
FROM SYSIBM.SYSDATABASE d;
