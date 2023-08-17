tee output/opdb__usersnoauthstring__V_TAG
SELECT count(*) AS userCount,
       HOST
FROM mysql.user
WHERE authentication_string = ''
GROUP BY HOST
;
notee
