SHOW GLOBAL STATUS
WHERE VARIABLE_NAME IN ('THREADS_CONNECTED',
                        'THREADS_RUNNING',
                        'QUERIES')
;
