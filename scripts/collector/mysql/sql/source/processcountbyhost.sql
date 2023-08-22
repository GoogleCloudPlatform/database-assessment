tee output/opdb__processcountbyhost__V_TAG
SELECT substring_index(HOST, ':', 1) AS 'host',
       count(*) AS 'count'
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
FROM information_schema.processlist
GROUP BY substring_index(HOST, ':', 1)
;
notee
