\ o output / opdb__indexdetail_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
    pg_relation_size(s.indexrelid) AS index_size,
    s.*,
    i.indisunique,
    i.indisprimary
FROM pg_stat_user_indexes AS s
    JOIN pg_index AS i USING(indexrelid)
