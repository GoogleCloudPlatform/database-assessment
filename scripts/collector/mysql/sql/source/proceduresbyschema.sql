tee output/opdb__proceduresbyschema__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ ROUTINE_SCHEMA,
                                       ROUTINE_NAME
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.ROUTINES
WHERE ROUTINE_TYPE = 'PROCEDURE'
  AND ROUTINE_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
ORDER BY ROUTINE_SCHEMA
;
notee
