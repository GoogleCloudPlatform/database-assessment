tee SQLOUTPUT_DIR/opdb__processesbydb__V_TAG
SELECT db,
       count(*) AS 'count'
FROM information_schema.processlist
GROUP BY db
ORDER BY 2 DESC
;
notee
