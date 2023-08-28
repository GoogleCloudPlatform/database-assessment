tee output/opdb__logbin__V_TAG
SELECT @@log_bin,@@log_slave_updates
, '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
;
notee
