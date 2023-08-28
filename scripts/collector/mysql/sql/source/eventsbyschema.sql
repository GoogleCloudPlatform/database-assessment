tee output/opdb__eventsbyschema__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ event_schema,
                                       event_name
                               , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.events
WHERE event_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
ORDER BY event_schema
;
notee
