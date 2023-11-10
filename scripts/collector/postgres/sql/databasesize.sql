\ o output / opdb__databasesize_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39),
    chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID,
    round(
        pg_database_size(datname) /(1024.0 * 1024 * 1024),
        2
    ) AS SIZE,
    *
FROM pg_stat_database
