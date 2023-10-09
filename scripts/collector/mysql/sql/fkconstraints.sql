SELECT /*+ MAX_EXECUTION_TIME(5000) */ CONSTRAINT_SCHEMA,
                                       CONSTRAINT_NAME,
                                       TABLE_SCHEMA,
                                       TABLE_NAME
                                , concat(char(39), @DMASOURCEID, char(39)) as DMA_SOURCE_ID, concat(char(39), @DMAMANUALID, char(39)) as DMA_MANUAL_ID
FROM information_schema.TABLE_CONSTRAINTS
WHERE table_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
  AND CONSTRAINT_TYPE= 'FOREIGN KEY'
;
