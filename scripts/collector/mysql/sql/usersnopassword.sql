SELECT count(*) AS userCount,
    HOST,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID
FROM mysql.user
WHERE password = ''
GROUP BY HOST;
