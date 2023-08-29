\o output/opdb__databasesize_:VTAG.csv
SELECT round(pg_database_size(datname)/(1024.0 * 1024 * 1024), 2) AS SIZE,
       *,
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_stat_database
