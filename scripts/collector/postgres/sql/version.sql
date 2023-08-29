\o output/opdb__version_:VTAG.csv
SELECT version(),
       chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID, chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
