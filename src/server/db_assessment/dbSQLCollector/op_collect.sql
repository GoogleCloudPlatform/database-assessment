set termout on pause on
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
set termout off
@@op_collect_init.sql
set termout on
prompt
prompt Step completed.

prompt
prompt Creating output directory
set termout off
!mkdir -p &outputdir
set termout on
prompt
prompt Setp completed.

prompt
prompt Collecting Optimus Prime data...
prompt

set termout off
@@op_collect_db_info.sql

set termout on
prompt Step completed.
prompt
prompt Optimus Prime data successfully extracted.
prompt
exit

