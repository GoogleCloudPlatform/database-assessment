tee output/opdb__processlist__V_TAG
SELECT id,
       HOST,
       db,
       command,
       TIME,
       state
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.processlist
;
notee
