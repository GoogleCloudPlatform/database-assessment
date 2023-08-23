\o output/opdb__tableiostats_:VTAG.csv
SELECT *,
       :DMA_SOURCE_ID
FROM pg_statio_user_tables
