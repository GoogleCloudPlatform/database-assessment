tee SQLOUTPUT_DIR/opdb__processlist__V_TAG
SELECT id,
       HOST,
       db,
       command,
       TIME,
       state
FROM information_schema.processlist
;
notee
