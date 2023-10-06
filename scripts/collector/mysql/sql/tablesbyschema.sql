SELECT /*+ MAX_EXECUTION_TIME(5000) */ table_schema,
                                       ROUND(SUM(data_length)/1024/1024/1024, 2) AS Data_Size_GB,
                                       ROUND(SUM(index_length)/1024/1024/1024, 2) AS Index_Size_GB
                                , concat(char(39), @DMASOURCEID, char(39)) as DMA_SOURCE_ID, concat(char(39), @DMAMANUALID, char(39)) as DMA_MANUAL_ID
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
  AND TABLE_TYPE <> 'VIEW'
GROUP BY 1
ORDER BY 2 DESC
;
