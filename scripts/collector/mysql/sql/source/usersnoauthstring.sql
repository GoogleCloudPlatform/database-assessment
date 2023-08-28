tee output/opdb__usersnoauthstring__V_TAG
SELECT count(*) AS userCount,
       HOST
                                , '''_DMASOURCEID_''' as DMA_SOURCE_ID, '''_DMAMANUALID_''' as MANUAL_ID
FROM mysql.user
WHERE authentication_string = ''
GROUP BY HOST
;
notee
