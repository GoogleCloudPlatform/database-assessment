\o output/opdb__replicationstats_:VTAG.csv
SELECT *,
       :DMA_SOURCE_ID
FROM pg_stat_replication
