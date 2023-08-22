tee output/opdb__tablesbyengine__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ ENGINE AS Storage_Engine,
                       COUNT(*) Tables_Count,
                       ROUND(SUM(data_length) / (1024*1024*1024), 2) Data_Size,
                       ROUND(SUM(index_length)/ (1024*1024*1024), 2) Index_Size
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID		
FROM information_schema.TABLES
WHERE ENGINE IS NOT NULL
  AND table_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
GROUP BY ENGINE
;
notee
