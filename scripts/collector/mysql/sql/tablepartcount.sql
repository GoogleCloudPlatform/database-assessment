SELECT
    /*+ MAX_EXECUTION_TIME(5000) */
    COUNT(*) AS PARTS_COUNT,
    TABLE_SCHEMA,
    TABLE_NAME,
    PARTITION_EXPRESSION,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID
FROM information_schema.PARTITIONS
WHERE table_schema NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
GROUP BY TABLE_SCHEMA,
    TABLE_NAME,
    PARTITION_EXPRESSION
HAVING COUNT(*) > 1;
