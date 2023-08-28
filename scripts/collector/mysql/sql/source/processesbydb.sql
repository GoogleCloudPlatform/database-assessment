tee output/opdb__processesbydb__V_TAG
SELECT db,
       count(*) AS 'count'
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM information_schema.processlist
GROUP BY db
ORDER BY 2 DESC
;
notee
