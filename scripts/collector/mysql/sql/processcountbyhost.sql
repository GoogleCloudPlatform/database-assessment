SELECT substring_index(HOST, ':', 1) AS 'host',
    count(*) AS 'count',
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID
FROM information_schema.processlist
GROUP BY substring_index(HOST, ':', 1);
