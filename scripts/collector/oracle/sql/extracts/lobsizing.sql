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
exec dbms_application_info.set_action('lobsizing');

WITH lobdata AS (
SELECT
    &s_c_con_id. AS CON_ID,
    c.owner,
    c.table_name,
    t.num_rows                AS table_num_rows,
    &s_t_segment_created.         AS table_seg_created,
    t.partitioned,
    c.column_name,
    c.data_type,
    tp.partition_name         AS table_partition_name,
    &s_tp_segment_created.        AS table_partition_seg_created,
    tp.num_rows               AS partition_num_rows,
    lp.lob_partition_name     AS lob_partition_name,
    &s_lp_segment_created.        AS lob_partition_seg_created,
    tp.subpartition_count,
    tsp.subpartition_name     AS table_subpartition_name,
    &s_tsp_segment_created.       AS table_subpartition_created,
    tsp.num_rows              AS subpartition_num_rows,
    lsp.lob_subpartition_name AS lob_subpartition_name,
    &s_lsp_segment_created.       AS lob_subpartition_seg_created,
    l.segment_name            AS lob_seg_name,
    s.segment_name            AS seg_name,
    s.partition_name          AS seg_partition_name,
    s.bytes                   AS seg_bytes,
    &s_lob_compression_col.             AS lob_compression,
    &s_lob_part_compression_col.            AS lob_partition_compression,
    &s_lob_subpart_compression_col.           AS lob_subpartition_compression,
    &s_lob_dedup_col.           AS lob_deduplication,
    &s_lob_part_dedup_col.          AS lob_partition_deduplication,
    &s_lob_subpart_dedup_col.         AS lob_subpartition_deduplication,
    CASE WHEN nvl(t.num_rows, 0) > 0 THEN round(s.bytes / t.num_rows) ELSE 0 END      AS table_avg_lob_bytes,
    CASE WHEN nvl(tp.num_rows, 0) > 0 THEN round(s.bytes / tp.num_rows) ELSE 0 END    AS partition_avg_lob_bytes,
    CASE WHEN nvl(tsp.num_rows, 0) > 0 THEN round(s.bytes / tsp.num_rows) ELSE 0 END  AS subpartition_avg_lob_bytes
FROM
         &s_tblprefix._tab_cols c
    JOIN &s_tblprefix._tables    t ON &s_t_con_id. = &s_c_con_id.
                         AND t.owner = c.owner
                         AND t.table_name = c.table_name
    JOIN &s_tblprefix._lobs    l ON &s_l_con_id. = &s_c_con_id.
                       AND l.owner = c.owner
                       AND l.table_name = c.table_name
                       AND l.column_name = c.column_name
    LEFT JOIN &s_tblprefix._tab_partitions    tp ON &s_tp_con_id. = &s_t_con_id.
                                       AND tp.table_owner = t.owner
                                       AND tp.table_name = t.table_name
    LEFT JOIN &s_tblprefix._tab_subpartitions tsp ON &s_tsp_con_id. = &s_tp_con_id.
                                           AND tsp.table_owner = tp.table_owner
                                           AND tsp.table_name = tp.table_name
                                           AND tsp.partition_name = tp.partition_name
    LEFT JOIN &s_tblprefix._lob_partitions    lp ON &s_lp_con_id. = &s_tp_con_id.
                                       AND lp.table_owner = tp.table_owner
                                       AND lp.table_name = tp.table_name
                                       AND lp.lob_name = l.segment_name
                                       AND lp.partition_name = tp.partition_name
    LEFT JOIN &s_tblprefix._lob_subpartitions lsp ON &s_lsp_con_id. = &s_lp_con_id.
                                           AND lsp.table_owner = lp.table_owner
                                           AND lsp.lob_name = lp.lob_name
                                           AND lsp.lob_partition_name = lp.lob_partition_name
                                           AND lsp.subpartition_name = tsp.subpartition_name
    LEFT JOIN &s_tblprefix._segments          s ON &s_s_con_id. = &s_l_con_id.
                                AND s.owner = l.owner
                                AND s.segment_name = l.segment_name
                                AND ( nvl(s.partition_name, '-') = (
                                       CASE WHEN lsp.subpartition_name IS NOT NULL THEN lsp.lob_subpartition_name
                                            WHEN lp.partition_name IS NOT NULL THEN lp.lob_partition_name
                                            ELSE '-'
                                       END)
                                    )
WHERE
    c.data_type LIKE '%LOB%'
    AND c.owner NOT IN (
@sql/extracts/exclude_schemas.sql
    )
)
SELECT  :v_pkey AS pkey,
       con_id,
       owner,
       table_name,
       table_num_rows,
       table_seg_created,
       partitioned,
       column_name,
       data_type,
       table_partition_name,
       table_partition_seg_created,
       partition_num_rows,
       lob_partition_name,
       lob_partition_seg_created,
       subpartition_count,
       table_subpartition_name,
       table_subpartition_created,
       subpartition_num_rows,
       lob_subpartition_name,
       lob_subpartition_seg_created,
       lob_seg_name,
       seg_name,
       seg_partition_name,
       LOB_COMPRESSION,
       LOB_PARTITION_COMPRESSION,
       LOB_SUBPARTITION_COMPRESSION,
       LOB_DEDUPLICATION,
       LOB_PARTITION_DEDUPLICATION,
       LOB_SUBPARTITION_DEDUPLICATION,
       seg_bytes,
       table_avg_lob_bytes,
       partition_avg_lob_bytes,
       subpartition_avg_lob_bytes,
       :v_dma_source_id AS dma_source_id, :v_manual_unique_id AS dma_manual_id
FROM lobdata;























