tee output/opdb__userswithshutdownprivs__V_TAG
SELECT count(*) AS userCount,
       HOST
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM mysql.user
WHERE (Shutdown_Priv = 'Y'
       OR Super_Priv = 'Y'
       OR Reload_Priv = 'Y')
GROUP BY HOST
;
notee
