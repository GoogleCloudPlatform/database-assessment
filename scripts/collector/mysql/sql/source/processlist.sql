tee output/opdb__processlist__V_TAG
SELECT id,
       HOST,
       db,
       command,
       TIME,
       state
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
FROM information_schema.processlist
;
notee
