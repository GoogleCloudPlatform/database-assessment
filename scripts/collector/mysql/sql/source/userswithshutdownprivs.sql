tee SQLOUTPUT_DIR/opdb__userswithshutdownprivs__V_TAG
SELECT count(*) AS userCount,
       HOST
FROM mysql.user
WHERE (Shutdown_Priv = 'Y'
       OR Super_Priv = 'Y'
       OR Reload_Priv = 'Y')
GROUP BY HOST
;
notee
