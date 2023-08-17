tee output/opdb__tablecount__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ COUNT(*) AS 'TABLE_COUNT',
      ROUND(sum(data_length) / (1024 * 1024 * 1024), 2) DATA,
      ROUND(sum(index_length) / (1024 * 1024 * 1024), 2) INDEXES
FROM information_schema.tables
WHERE table_schema NOT IN ('mysql',
                           'performance_schema',
                           'information_schema',
                           'sys')
;
notee
