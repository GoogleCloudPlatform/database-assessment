tee SQLOUTPUT_DIR/opdb__usersnohost__V_TAG
SELECT count(*) AS userCount,
       HOST
FROM mysql.user
WHERE HOST = '%'
  OR HOST = ''
GROUP BY HOST
;
notee
