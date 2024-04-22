column c_con_id   new_value v_c_con_id   noprint
column t_con_id   new_value v_t_con_id   noprint
column l_con_id   new_value v_l_con_id   noprint
column tp_con_id  new_value v_tp_con_id  noprint
column tsp_con_id new_value v_tsp_con_id noprint
column lp_con_id  new_value v_lp_con_id  noprint
column lsp_con_id new_value v_lsp_con_id noprint
column s_con_id   new_value v_s_con_id   noprint

column t_segment_created   new_value  v_t_segment_created
column tp_segment_created  new_value  v_tp_segment_created
column lp_segment_created  new_value  v_lp_segment_created
column tsp_segment_created new_value  v_tsp_segment_created
column lsp_segment_created new_value  v_lsp_segment_created


SELECT CASE WHEN &v_is_container != 0 THEN 'c.con_id'   ELSE '''N/A''' END as c_con_id,
       CASE WHEN &v_is_container != 0 THEN 't.con_id'   ELSE '''N/A''' END as t_con_id,
       CASE WHEN &v_is_container != 0 THEN 'l.con_id'   ELSE '''N/A''' END as l_con_id,
       CASE WHEN &v_is_container != 0 THEN 'tp.con_id'  ELSE '''N/A''' END as tp_con_id,
       CASE WHEN &v_is_container != 0 THEN 'tsp.con_id' ELSE '''N/A''' END as tsp_con_id,
       CASE WHEN &v_is_container != 0 THEN 'lp.con_id'  ELSE '''N/A''' END as lp_con_id,
       CASE WHEN &v_is_container != 0 THEN 'lsp.con_id' ELSE '''N/A''' END as lsp_con_id,
       CASE WHEN &v_is_container != 0 THEN 's.con_id'   ELSE '''N/A''' END as s_con_id
FROM DUAL;

SELECT  CASE WHEN '&v_dbversion' LIKE '9%' OR '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '''N/A''' ELSE 't.segment_created'   END as t_segment_created,
        CASE WHEN '&v_dbversion' LIKE '9%' OR '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '''N/A''' ELSE 'tp.segment_created'  END as tp_segment_created,
        CASE WHEN '&v_dbversion' LIKE '9%' OR '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '''N/A''' ELSE 'lp.segment_created'  END as lp_segment_created,
        CASE WHEN '&v_dbversion' LIKE '9%' OR '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '''N/A''' ELSE 'tsp.segment_created' END as tsp_segment_created,
        CASE WHEN '&v_dbversion' LIKE '9%' OR '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN '''N/A''' ELSE 'lsp.segment_created' END as lsp_segment_created
FROM DUAL;


COLUMN PARTITIONED FORMAT A40
COLUMN COLUMN_NAME FORMAT A40
COLUMN DATA_TYPE FORMAT A40
COLUMN TABLE_PARTITION_NAME FORMAT A40
COLUMN TABLE_PARTITION_SEG_CREATED FORMAT A40
COLUMN LOB_PARTITION_NAME FORMAT A40
COLUMN LOB_PARTITION_SEG_CREATED FORMAT A40
COLUMN TABLE_SUBPARTITION_NAME FORMAT A40
COLUMN TABLE_SUBPARTITION_CREATED FORMAT A40
COLUMN LOB_SUBPARTITION_NAME FORMAT A40
COLUMN LOB_SUBPARTITION_SEG_CREATED FORMAT A40
COLUMN LOB_SEG_NAME FORMAT A40
COLUMN SEG_NAME FORMAT A40
COLUMN SEG_PARTITION_NAME FORMAT A40
COLUMN LOB_COMPRESSION FORMAT A40
COLUMN LOB_PARTITION_COMPRESSION FORMAT A40
COLUMN LOB_SUBPARTITION_COMPRESSION FORMAT A40
COLUMN LOB_DEDUPLICATION FORMAT A40
COLUMN LOB_PARTITION_DEDUPLICATION FORMAT A40
COLUMN LOB_SUBPARTITION_DEDUPLICATION FORMAT A40

spool &outputdir/opdb__lobsizing__&v_tag
prompt PKEY|CON_ID|OWNER|TABLE_NAME|TABLE_NUM_ROWS|TAB|PARTITIONED|COLUMN_NAME|DATA_TYPE|TABLE_PARTITION_NAME|TABLE_PARTITION_SEG_CREATED|PARTITION_NUM_ROWS|LOB_PARTITION_NAME|LOB_PARTITION_SEG_CREATED|SUBPARTITION_COUNT|TABLE_SUBPARTITION_NAME|TABLE_SUBPARTITION_CREATED|SUBPARTITION_NUM_ROWS|LOB_SUBPARTITION_NAME|LOB_SUBPARTITION_SEG_CREATED|LOB_SEG_NAME|SEG_NAME|SEG_PARTITION_NAME|LOB_COMPRESSION|LOB_PARTITION_COMPRESSION|LOB_SUBPARTITION_COMPRESSION|LOB_DEDUPLICATION|LOB_PARTITION_DEDUPLICATION|LOB_SUBPARTITION_DEDUPLICATION|SEG_BYTES|TABLE_AVG_LOB_BYTES|PARTITION_AVG_LOB_BYTES|SUBPARTITION_AVG_LOB_BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH lobdata AS (
SELECT
    &v_c_con_id AS CON_ID,
    c.owner,
    c.table_name,
    t.num_rows                AS table_num_rows,
    &v_t_segment_created         AS table_seg_created,
    t.partitioned,
    c.column_name,
    c.data_type,
    tp.partition_name         AS table_partition_name,
    &v_tp_segment_created        AS table_partition_seg_created,
    tp.num_rows               AS partition_num_rows,
    lp.lob_partition_name     AS lob_partition_name,
    &v_lp_segment_created        AS lob_partition_seg_created,
    tp.subpartition_count,
    tsp.subpartition_name     AS table_subpartition_name,
    &v_tsp_segment_created       AS table_subpartition_created,
    tsp.num_rows              AS subpartition_num_rows,
    lsp.lob_subpartition_name AS lob_subpartition_name,
    &v_lsp_segment_created       AS lob_subpartition_seg_created,
    l.segment_name            AS lob_seg_name,
    s.segment_name            AS seg_name,
    s.partition_name          AS seg_partition_name,
    s.bytes                   AS seg_bytes,
    &v_lob_compression_col             AS lob_compression,
    &v_lob_part_compression_col            AS lob_partition_compression,
    &v_lob_subpart_compression_col           AS lob_subpartition_compression,
    &v_lob_dedup_col           AS lob_deduplication,
    &v_lob_part_dedup_col          AS lob_partition_deduplication,
    &v_lob_subpart_dedup_col         AS lob_subpartition_deduplication,
    CASE WHEN nvl(t.num_rows, 0) > 0 THEN round(s.bytes / t.num_rows) ELSE 0 END      AS table_avg_lob_bytes,
    CASE WHEN nvl(tp.num_rows, 0) > 0 THEN round(s.bytes / tp.num_rows) ELSE 0 END    AS partition_avg_lob_bytes,
    CASE WHEN nvl(tsp.num_rows, 0) > 0 THEN round(s.bytes / tsp.num_rows) ELSE 0 END  AS subpartition_avg_lob_bytes
FROM
         &v_tblprefix._tab_cols c
    JOIN &v_tblprefix._tables    t ON &v_t_con_id = &v_c_con_id
                         AND t.owner = c.owner
                         AND t.table_name = c.table_name
    JOIN &v_tblprefix._lobs    l ON &v_l_con_id = &v_c_con_id
                       AND l.owner = c.owner
                       AND l.table_name = c.table_name
                       AND l.column_name = c.column_name
    LEFT JOIN &v_tblprefix._tab_partitions    tp ON &v_tp_con_id = &v_t_con_id
                                       AND tp.table_owner = t.owner
                                       AND tp.table_name = t.table_name
    LEFT JOIN &v_tblprefix._tab_subpartitions tsp ON &v_tsp_con_id = &v_tp_con_id
                                           AND tsp.table_owner = tp.table_owner
                                           AND tsp.table_name = tp.table_name
                                           AND tsp.partition_name = tp.partition_name
    LEFT JOIN &v_tblprefix._lob_partitions    lp ON &v_lp_con_id = &v_tp_con_id
                                       AND lp.table_owner = tp.table_owner
                                       AND lp.table_name = tp.table_name
                                       AND lp.lob_name = l.segment_name
                                       AND lp.partition_name = tp.partition_name
    LEFT JOIN &v_tblprefix._lob_subpartitions lsp ON &v_lsp_con_id = &v_lp_con_id
                                           AND lsp.table_owner = lp.table_owner
                                           AND lsp.lob_name = lp.lob_name
                                           AND lsp.lob_partition_name = lp.lob_partition_name
                                           AND lsp.subpartition_name = tsp.subpartition_name
    LEFT JOIN &v_tblprefix._segments          s ON &v_s_con_id = &v_l_con_id
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
@&EXTRACTSDIR/exclude_schemas.sql
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
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM lobdata;
spool off


COLUMN PARTITIONED
COLUMN COLUMN_NAME
COLUMN DATA_TYPE
COLUMN TABLE_PARTITION_NAME
COLUMN TABLE_PARTITION_SEG_CREATED
COLUMN LOB_PARTITION_NAME
COLUMN LOB_PARTITION_SEG_CREATED
COLUMN TABLE_SUBPARTITION_NAME
COLUMN TABLE_SUBPARTITION_CREATED
COLUMN LOB_SUBPARTITION_NAME
COLUMN LOB_SUBPARTITION_SEG_CREATED
COLUMN LOB_SEG_NAME
COLUMN SEG_NAME
COLUMN SEG_PARTITION_NAME
COLUMN LOB_COMPRESSION
COLUMN LOB_PARTITION_COMPRESSION
COLUMN LOB_SUBPARTITION_COMPRESSION
COLUMN LOB_DEDUPLICATION
COLUMN LOB_PARTITION_DEDUPLICATION
COLUMN LOB_SUBPARTITION_DEDUPLICATION
