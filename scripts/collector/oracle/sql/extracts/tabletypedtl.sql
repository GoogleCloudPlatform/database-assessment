/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
COLUMN TEMPORARY FORMAT A20
COLUMN SECONDARY FORMAT A20
COLUMN NESTED    FORMAT A20
COLUMN CLUSTERED_TABLE FORMAT A20
COLUMN OBJECT_TABLE FORMAT A20
COLUMN XML_TABLE FORMAT A20
COLUMN PARTITIONING_TYPE FORMAT A20
COLUMN SUBPARTITIONING_TYPE FORMAT A20

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
    :xml_select_sql := '(SELECT NULL AS con_id, NULL AS owner, NULL AS table_name FROM dual WHERE 1=2)';
  END IF;
END;
/

SELECT :xml_select_sql AS p_xml_select FROM dual;

spool &outputdir/opdb__tabletypedtl__&v_tag
prompt PKEY|CON_ID|OWNER|TABLE_NAME|PAR|IOT_TYPE|NESTED|TEMPORARY|SECONDARY|CLUSTERED_TABLE|OBJECT_TABLE|XML_TABLE|PARTITIONING_TYPE|SUBPARTITIONING_TYPE|PARTITION_COUNT|SUBPARTITION_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH tblinfo AS (
SELECT
    &v_a_con_id AS con_id,
    a.owner,
    a.table_name,
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
    'N' AS object_table,
    'N' AS xml_table
FROM &v_tblprefix._tables a
WHERE a.owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
UNION ALL
SELECT
    &v_b_con_id AS con_id,
    b.owner,
    b.table_name,
    'NO' partitioned,
    NULL iot_type,
    'NO' nested,
    'N' temporary,
    'N' secondary,
    'N' clustered_table,
    'N' AS object_table,
    'Y' AS xml_table
FROM &v_xml_select b
WHERE b.owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
UNION ALL
SELECT
    &v_c_con_id AS con_id,
    c.owner,
    c.table_name,
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
    'Y' AS object_table,
    'N' AS xml_table
FROM &v_tblprefix._object_tables c
WHERE c.owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
),
subpartinfo AS (
SELECT &v_d_con_id AS con_id,
       d.table_owner,
       d.table_name,
       count(1) cnt
FROM &v_tblprefix._tab_subpartitions d
WHERE d.table_owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
       )
GROUP BY &v_d_con_id,
       d.table_owner,
       d.table_name
)
SELECT :v_pkey AS pkey,
       a.con_id,
       a.owner,
       a.table_name,
       a.partitioned,
       a.iot_type,
       a.nested,
       a.temporary,
       a.secondary,
       a.clustered_table,
       a.object_table,
       a.xml_table,
       p.partitioning_type,
       p.subpartitioning_type,
       p.partition_count,
       sp.cnt AS subpartition_count,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM  tblinfo a
LEFT OUTER JOIN &v_tblprefix._part_tables p
              ON a.owner = p.owner
               AND a.table_name = p.table_name
               AND a.con_id = &v_p_con_id
LEFT OUTER JOIN subpartinfo sp
              ON sp.table_owner = p.owner
               AND sp.table_name = p.table_name
               AND sp.con_id = &v_p_con_id
;
spool off
COLUMN TEMPORARY CLEAR
COLUMN SECONDARY CLEAR
COLUMN NESTED CLEAR
COLUMN CLUSTERED_TABLE CLEAR
COLUMN OBJECT_TABLE CLEAR
COLUMN XML_TABLE CLEAR
COLUMN PARTITIONING_TYPE CLEAR
COLUMN SUBPARTITIONING_TYPE CLEAR
