tee output/opdb__usersnoauthstring__V_TAG
SELECT count(*) AS userCount,
       HOST
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
FROM mysql.user
WHERE authentication_string = ''
GROUP BY HOST
;
notee
