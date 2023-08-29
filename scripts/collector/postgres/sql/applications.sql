\o output/opdb__applications_:VTAG.csv
SELECT application_name,
       count(*), 
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
FROM pg_stat_activity
GROUP BY 1
