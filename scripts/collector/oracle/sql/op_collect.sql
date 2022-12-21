/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

set termout on pause on
prompt
prompt ***********************************************************************************
prompt
prompt !!! ATTENTION !!!
prompt
prompt The Database Migration Assessment scripts utilize views and packages that are licensed 
prompt separately under the Oracle Diagnostics Pack and Oracle Tuning Pack. Please ensure 
prompt you have the correct licenses to run this utility. See the README for further details.
prompt
prompt
prompt ***********************************************************************************
prompt

prompt Initializing Database Migration Assessment Collector...
prompt
SET DEFINE "&"
DEFINE SQLDIR=&2
DEFINE v_dodiagnostics=&3
DEFINE EXTRACTSDIR=&SQLDIR/extracts
set termout off
@@op_collect_init.sql
set termout on
prompt
prompt Step completed.


prompt
prompt Collecting Database Migration Assessment data...
prompt

set termout off
@&SQLDIR/op_collect_db_info.sql &SQLDIR

set termout on
prompt Step completed.
prompt
prompt Database Migration Assessment data successfully extracted.
prompt
exit

