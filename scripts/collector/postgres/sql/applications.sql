\ o output / opdb__applications_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
    application_name as application_name,
    count(*) as application_count
FROM pg_stat_activity
GROUP BY 1
