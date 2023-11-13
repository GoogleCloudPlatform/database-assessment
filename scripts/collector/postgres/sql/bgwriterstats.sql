\ o output / opdb__bgwriterstats_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
    *
FROM pg_stat_bgwriter
