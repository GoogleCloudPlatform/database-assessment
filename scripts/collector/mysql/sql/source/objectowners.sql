tee output/opdb__objectowners__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ DEFINER
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.views
WHERE TABLE_SCHEMA NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
UNION
SELECT DEFINER
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND ROUTINE_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
UNION
SELECT DEFINER
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.ROUTINES
WHERE ROUTINE_TYPE = 'FUNCTION'
  AND ROUTINE_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
UNION
SELECT DEFINER
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
UNION
SELECT DEFINER
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.events
WHERE event_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
;
notee
