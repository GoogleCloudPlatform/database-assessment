tee output/opdb__functionsbyschema__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ ROUTINE_SCHEMA,
                                       ROUTINE_NAME
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID				
FROM information_schema.ROUTINES
WHERE ROUTINE_TYPE = 'FUNCTION'
  AND ROUTINE_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
ORDER BY ROUTINE_SCHEMA
;
notee
