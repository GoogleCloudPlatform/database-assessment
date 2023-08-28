tee output/opdb__datadir__V_TAG
SELECT @@datadir
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
;
notee
