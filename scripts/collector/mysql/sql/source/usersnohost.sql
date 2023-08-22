tee output/opdb__usersnohost__V_TAG
SELECT count(*) AS userCount,
       HOST
                                , '_DMA_SOURCE_ID_' as DMA_SOURCE_ID
FROM mysql.user
WHERE HOST = '%'
  OR HOST = ''
GROUP BY HOST
;
notee
