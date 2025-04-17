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
exec dbms_application_info.set_action('tabletypedtl');


WITH tblinfo AS (
SELECT
    &s_a_con_id. AS con_id,
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
FROM &s_tblprefix._tables a
WHERE a.owner NOT IN (
@sql/extracts/exclude_schemas.sql
       )
UNION ALL
SELECT
    &s_b_con_id. AS con_id,
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
FROM &s_xml_select_dtl. b
WHERE b.owner NOT IN (
@sql/extracts/exclude_schemas.sql
       )
UNION ALL
SELECT
    &s_c_con_id. AS con_id,
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
FROM &s_tblprefix._object_tables c
WHERE c.owner NOT IN (
@sql/extracts/exclude_schemas.sql
       )
),
subpartinfo AS (
SELECT &s_d_con_id. AS con_id,
       d.table_owner,
       d.table_name,
       count(1) cnt
FROM &s_tblprefix._tab_subpartitions d
WHERE d.table_owner NOT IN (
@sql/extracts/exclude_schemas.sql
       )
GROUP BY &s_d_con_id.,
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
LEFT OUTER JOIN &s_tblprefix._part_tables p
              ON a.owner = p.owner
               AND a.table_name = p.table_name
               AND a.con_id = &s_p_con_id.
LEFT OUTER JOIN subpartinfo sp
              ON sp.table_owner = p.owner
               AND sp.table_name = p.table_name
               AND sp.con_id = &s_p_con_id.
;









