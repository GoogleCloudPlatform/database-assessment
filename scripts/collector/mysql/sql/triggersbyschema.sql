SELECT /*+ MAX_EXECUTION_TIME(5000) */ TRIGGER_SCHEMA,
                                       TRIGGER_NAME
                                , concat(char(39), @DMASOURCEID, char(39)) as DMA_SOURCE_ID, concat(char(39), @DMAMANUALID, char(39)) as DMA_MANUAL_ID
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
ORDER BY TRIGGER_SCHEMA
;
