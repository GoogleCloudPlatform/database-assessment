SELECT db,
       count(*) AS 'count'
                                , concat(char(39), @DMASOURCEID, char(39)) as DMA_SOURCE_ID, concat(char(39), @DMAMANUALID, char(39)) as DMA_MANUAL_ID
FROM information_schema.processlist
GROUP BY db
ORDER BY 2 DESC
;
