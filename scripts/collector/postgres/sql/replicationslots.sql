\o output/opdb__replicationslots_:VTAG.csv
SELECT *,
       :DMA_SOURCE_ID
FROM pg_replication_slots
