tee output/opdb__logbin__V_TAG
SELECT @@log_bin,@@log_slave_updates
, '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
;
notee
