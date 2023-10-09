SELECT /*+ MAX_EXECUTION_TIME(5000) */ tables.table_schema,
                                       tables.table_name,
                                       tables.table_rows
                                , concat(char(39), @DMASOURCEID, char(39)) as DMA_SOURCE_ID, concat(char(39), @DMAMANUALID, char(39)) as DMA_MANUAL_ID
FROM information_schema.tables
LEFT JOIN
  (SELECT table_schema,
          TABLE_NAME
   FROM information_schema.statistics
   GROUP BY table_schema,
            TABLE_NAME,
            index_name
   HAVING SUM(CASE
                  WHEN non_unique = 0
                       AND NULLABLE != 'YES' THEN 1
                  ELSE 0
              END) = COUNT(*)) puks ON tables.table_schema = puks.table_schema
AND tables.table_name = puks.table_name
WHERE puks.table_name IS NULL
  AND tables.table_schema NOT IN ('mysql',
                                  'information_schema',
                                  'performance_schema',
                                  'sys')
  AND tables.table_type = 'BASE TABLE'
;
