tee output/opdb__usersnopasswword__V_TAG
SELECT count(*) AS userCount,
       HOST
FROM mysql.user
WHERE password = ''
GROUP BY HOST
;
notee
