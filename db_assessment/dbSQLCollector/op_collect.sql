set termout on pause on
prompt
prompt ===================================================================================
prompt Optimus Prime Database Assessment Collector {{ script_version}}
prompt ===================================================================================
prompt
prompt ***********************************************************************************
prompt
prompt !!! WARNING !!!
prompt
prompt Optimus prime accesses views and packages that are licensed separately under
prompt the Oracle Diagnostics Pack and Oracle Tuning Pack. Please ensure you have
prompt the correct licenses to run this utility. See the README for further details.
prompt
prompt
prompt ***********************************************************************************
prompt

prompt Initializing Optimus Prime Collector...
prompt
@@op_collect_init.sql
prompt
prompt Step completed.

prompt Creating output directory
!mkdir -p &outputdir
prompt
prompt Setp completed.

prompt
prompt Collecting Optimus Prime data...
prompt

@@op_collect_db_info.sql

set termout on
prompt Step completed.  Optimus Prime data successfully extracted.
prompt

prompt 
prompt Preparing files for compression.
HOST sed -i -r -f &seddir/op_sed_cleanup.sed &outputdir/*log
HOST sed -i -r '1i\ ' &outputdir/*log
HOST grep ORA- &outputdir/*log >&outputdir/errors.log

prompt Archiving output files
host cd  &outputdir; tar  cvzf opdb__&v_tag..tgz --remove-files *log 

prompt Step completed.
prompt

prompt Restoring original environment...
--@@op_collect_restore.sql
prompt
prompt Step completed.
prompt

prompt ===================================================================================
prompt Optimus Prime Database Assessment Collector completed.
prompt ===================================================================================
prompt
exit

