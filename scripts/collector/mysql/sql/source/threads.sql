tee SQLOUTPUT_DIR/opdb__threads__V_TAG
SHOW GLOBAL STATUS
WHERE VARIABLE_NAME IN ('THREADS_CONNECTED',
                        'THREADS_RUNNING',
                        'QUERIES')
;
notee
