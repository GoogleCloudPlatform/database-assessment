\o output/opdb__indexdetail_:VTAG.csv
SELECT pg_relation_size(s.indexrelid) AS index_size,
       s.*,
       i.indisunique,
       i.indisprimary,
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_stat_user_indexes AS s
JOIN pg_index AS i USING(indexrelid)
