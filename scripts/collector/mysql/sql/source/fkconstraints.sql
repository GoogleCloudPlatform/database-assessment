tee SQLOUTPUT_DIR/opdb__fkconstraints__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ CONSTRAINT_SCHEMA,
                                       CONSTRAINT_NAME,
                                       TABLE_SCHEMA,
                                       TABLE_NAME
FROM information_schema.TABLE_CONSTRAINTS
WHERE table_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
  AND CONSTRAINT_TYPE= 'FOREIGN KEY'
;
notee
