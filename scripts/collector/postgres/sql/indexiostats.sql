\o output/opdb__indexiostats_:VTAG.csv
SELECT *,
       :DMA_SOURCE_ID
FROM pg_statio_user_indexes
