tee output/opdb__tablepartcount__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ COUNT(*) AS PARTS_COUNT,
                                       TABLE_SCHEMA,
                                       TABLE_NAME,
                                       PARTITION_EXPRESSION
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.PARTITIONS
WHERE table_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
GROUP BY TABLE_SCHEMA,
         TABLE_NAME,
         PARTITION_EXPRESSION
HAVING COUNT(*) > 1
;
notee
