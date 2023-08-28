tee output/opdb__version_comment__V_TAG
SELECT @@version_comment
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
;
notee
