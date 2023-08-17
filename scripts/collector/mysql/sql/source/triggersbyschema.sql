tee output/opdb__triggersbyschema__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ TRIGGER_SCHEMA,
                                       TRIGGER_NAME
FROM information_schema.TRIGGERS
WHERE TRIGGER_SCHEMA NOT IN ('mysql',
                             'information_schema',
                             'performance_schema',
                             'sys')
ORDER BY TRIGGER_SCHEMA
;
notee
