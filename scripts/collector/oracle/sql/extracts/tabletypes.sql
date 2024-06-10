--
-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License").
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
--
COLUMN TEMPORARY FORMAT A20
COLUMN SECONDARY FORMAT A20
COLUMN NESTED    FORMAT A20
COLUMN CLUSTERED_TABLE FORMAT A20
COLUMN OBJECT_TABLE FORMAT A20
COLUMN XML_TABLE FORMAT A20

VARIABLE xml_select_sql VARCHAR2(100);
COLUMN p_xml_select new_value v_xml_select noprint

DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt
  FROM &v_tblprefix._views
  WHERE view_name = upper('&v_tblprefix._XML_TABLES');

  IF cnt > 0 THEN
    :xml_select_sql := '&v_tblprefix._XML_TABLES';
  ELSE
    :xml_select_sql := '(SELECT NULL AS con_id, NULL AS owner FROM dual WHERE 1=2)';
  END IF;
END;
/

SELECT :xml_select_sql AS p_xml_select FROM dual;

spool &outputdir/opdb__tabletypes__&v_tag
prompt PKEY|CON_ID|OWNER|PAR|IOT_TYPE|NESTED|TEMPORARY|SECONDARY|CLUSTERED_TABLE|TABLE_COUNT|OBJECT_TABLE|XML_TABLE|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH tblinfo AS (
SELECT
    &v_a_con_id AS con_id,
    a.owner,
    a.partitioned,
    a.iot_type,
    a.nested,
    a.temporary,
    a.secondary,
    CASE
        WHEN a.cluster_name IS NULL THEN
            'N'
        ELSE
            'Y'
    END      AS clustered_table,
    COUNT(1) AS table_count,
    'N' AS object_table,
    'N' AS xml_table
FROM &v_tblprefix._tables a
WHERE a.owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
GROUP BY
    &v_a_con_id,
    a.owner,
    a.partitioned,
    a.iot_type,
    a.nested,
    a.temporary,
    a.secondary,
    CASE
        WHEN a.cluster_name IS NULL THEN
            'N'
        ELSE
            'Y'
    END,
    'N',
    'N'
UNION ALL
SELECT
    &v_b_con_id AS con_id,
    b.owner,
    'NO' partitioned,
    NULL iot_type,
    'NO' nested,
    'N' temporary,
    'N' secondary,
    'N' clustered_table,
    COUNT(1) AS table_count,
    'N' AS object_table,
    'Y' AS xml_table
FROM &v_xml_select b
WHERE b.owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
GROUP BY
    &v_b_con_id,
    b.owner
UNION ALL
SELECT
    &v_c_con_id AS con_id,
    c.owner,
    c.partitioned,
    c.iot_type,
    c.nested,
    c.temporary,
    c.secondary,
    CASE
        WHEN c.cluster_name IS NULL THEN
            'N'
        ELSE
            'Y'
    END      AS clustered_table,
    COUNT(1) AS table_count,
    'Y' AS object_table,
    'N' AS xml_table
FROM &v_tblprefix._object_tables c
WHERE c.owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
GROUP BY
    &v_c_con_id,
    c.owner,
    c.partitioned,
    c.iot_type,
    c.nested,
    c.temporary,
    c.secondary,
    CASE
        WHEN c.cluster_name IS NULL THEN
            'N'
        ELSE
            'Y'
    END,
    'Y',
    'N'
)
SELECT :v_pkey AS pkey,
       con_id,
       owner,
       partitioned,
       iot_type,
       nested,
       temporary,
       secondary,
       clustered_table,
       table_count,
       object_table,
       xml_table,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM  tblinfo;
spool off
COLUMN TEMPORARY CLEAR
COLUMN SECONDARY CLEAR
COLUMN NESTED CLEAR
COLUMN CLUSTERED_TABLE CLEAR
COLUMN OBJECT_TABLE CLEAR
COLUMN XML_TABLE CLEAR
