SELECT
    /*+ MAX_EXECUTION_TIME(5000) */
    event_schema,
    event_name,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID
FROM information_schema.events
WHERE event_schema NOT IN (
        'mysql',
        'information_schema',
        'performance_schema',
        'sys'
    )
ORDER BY event_schema;
