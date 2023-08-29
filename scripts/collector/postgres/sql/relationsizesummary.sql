\o output/opdb__relationsizesummary_:VTAG.csv
SELECT pg_total_relation_size(relid) AS total_size,
       pg_relation_size(relid) AS SIZE,
       *,
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_stat_user_tables
