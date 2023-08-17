tee SQLOUTPUT_DIR/opdb__eventsbyschema__V_TAG
SELECT /*+ MAX_EXECUTION_TIME(5000) */ event_schema,
                                       event_name
FROM information_schema.events
WHERE event_schema NOT IN ('mysql',
                           'information_schema',
                           'performance_schema',
                           'sys')
ORDER BY event_schema
;
notee
