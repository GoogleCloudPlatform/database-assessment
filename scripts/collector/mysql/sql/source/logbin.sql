tee SQLOUTPUT_DIR/opdb__logbin__V_TAG
SELECT @@log_bin,@@log_slave_updates
;
notee
