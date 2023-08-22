tee output/opdb__processesbydb__V_TAG
SELECT db,
       count(*) AS 'count'
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
FROM information_schema.processlist
GROUP BY db
ORDER BY 2 DESC
;
notee
