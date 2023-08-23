\o output/opdb__bgwriterstats_:VTAG.csv
SELECT *,
       :DMA_SOURCE_ID
FROM pg_stat_bgwriter
