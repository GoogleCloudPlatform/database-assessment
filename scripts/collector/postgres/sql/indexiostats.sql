\o output/opdb__indexiostats_:VTAG.csv
SELECT *,
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_statio_user_indexes
