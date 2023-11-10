\ o output / opdb__relationsizesummary_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39),
    chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID,
    pg_total_relation_size(relid) AS total_size,
    pg_relation_size(relid) AS SIZE,
    *
FROM pg_stat_user_tables
