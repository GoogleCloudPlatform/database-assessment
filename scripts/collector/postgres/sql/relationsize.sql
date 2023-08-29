\o output/opdb__relationsize_:VTAG.csv
SELECT round(pg_relation_size(relid)/(1024.0 * 1024 * 1024), 2) AS SIZE,
       relname,
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_stat_user_tables
WHERE relid not in
    (SELECT indrelid
     FROM pg_index
     WHERE indisprimary)
