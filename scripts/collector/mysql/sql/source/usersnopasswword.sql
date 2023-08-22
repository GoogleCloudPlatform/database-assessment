tee output/opdb__usersnopassword__V_TAG
SELECT count(*) AS userCount,
       HOST
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
FROM mysql.user
WHERE password = ''
GROUP BY HOST
;
notee
