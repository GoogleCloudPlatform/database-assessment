\o output/opdb__indexdetail_:VTAG.csv
SELECT pg_relation_size(s.indexrelid) AS index_size,
       s.*,
       i.indisunique,
       i.indisprimary,
       :DMA_SOURCE_ID
FROM pg_stat_user_indexes AS s
JOIN pg_index AS i USING(indexrelid)
