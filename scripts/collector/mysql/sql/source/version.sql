tee output/opdb__version__V_TAG
SELECT version()
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
;
notee
