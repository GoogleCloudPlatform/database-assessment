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
set feedback on
prompt Granting privileges for statspack views
set feedback off


set verify off

--accept dbusername char prompt "Please enter the DB Local Username(Or CDB Username) to receive all required grants: "

GRANT SELECT ON stats$snapshot TO &&dbusername;
GRANT SELECT ON stats$sql_summary TO &&dbusername;
GRANT SELECT ON stats$osstat TO &&dbusername;
GRANT SELECT ON stats$osstatname TO &&dbusername;
GRANT SELECT ON stats$sysstat TO &&dbusername;
GRANT SELECT ON stats$sys_time_model TO &&dbusername;
GRANT SELECT ON stats$time_model_statname TO &&dbusername;
GRANT SELECT ON stats$system_event TO &&dbusername;
GRANT SELECT ON v_$event_name TO &&dbusername;
GRANT SELECT ON stats$iostat_function TO &&dbusername;
GRANT SELECT ON stats$iostat_function_name TO &&dbusername;
GRANT SELECT ON v_$instance TO &&dbusername;
GRANT SELECT ON gv_$instance TO &&dbusername;
GRANT SELECT ON v_$database TO &&dbusername;
GRANT SELECT ON gv_$database TO &&dbusername;
GRANT SELECT ON gv_$archived_log TO &&dbusername;
GRANT SELECT ON v_$rman_backup_job_details TO &&dbusername;
GRANT SELECT ON system.logstdby$skip_support TO &&dbusername;
GRANT SELECT ON dba_tab_cols TO &&dbusername;
GRANT SELECT ON dba_tab_columns TO &&dbusername;
GRANT SELECT ON dba_segments TO &&dbusername;
GRANT SELECT ON dba_users TO &&dbusername;
GRANT SELECT ON dba_tables TO &&dbusername;
GRANT SELECT ON dba_tab_partitions TO &&dbusername;
GRANT SELECT ON dba_tab_subpartitions TO &&dbusername;
GRANT SELECT ON dba_cpu_usage_statistics TO &&dbusername;
GRANT SELECT ON dba_feature_usage_statistics TO &&dbusername;
GRANT SELECT ON dba_high_water_mark_statistics TO &&dbusername;
GRANT SELECT ON dba_db_links TO &&dbusername;
GRANT SELECT ON dba_objects TO &&dbusername;
GRANT SELECT ON dba_synonyms TO &&dbusername;
GRANT SELECT ON dba_views TO &&dbusername;
GRANT SELECT ON dba_mviews TO &&dbusername;
GRANT SELECT ON dba_external_tables TO &&dbusername;
GRANT SELECT ON dba_indexes TO &&dbusername;
GRANT SELECT ON dba_lobs TO &&dbusername;
GRANT SELECT ON dba_lob_partitions TO &&dbusername;
GRANT SELECT ON dba_lob_subpartitions TO &&dbusername;
GRANT SELECT ON dba_source TO &&dbusername;
GRANT SELECT ON dba_constraints TO &&dbusername;
GRANT SELECT ON dba_object_tables TO &&dbusername;
GRANT SELECT ON dba_xml_tables TO &&dbusername;
GRANT SELECT ON dba_triggers TO &&dbusername;

GRANT SELECT ON dba_data_files TO &&dbusername;
GRANT SELECT ON dba_segments TO &&dbusername;
GRANT SELECT ON dba_temp_files TO &&dbusername;

GRANT SELECT ON v_$version TO &&dbusername;
GRANT SELECT ON v_$log_history TO &&dbusername;
GRANT SELECT ON nls_database_parameters TO &&dbusername;
GRANT SELECT ON v_$sgastat TO &&dbusername;
GRANT SELECT ON gv_$sgastat TO &&dbusername;
GRANT SELECT ON v_$pgastat TO &&dbusername;
GRANT SELECT ON gv_$pgastat TO &&dbusername;
GRANT SELECT ON v_$log TO &&dbusername;
GRANT SELECT ON v_$logfile TO &&dbusername;
GRANT SELECT ON gv_$process TO &&dbusername;


GRANT SELECT ON gv_$parameter TO &&dbusername;
GRANT SELECT ON gv_$archive_dest TO &&dbusername;
GRANT SELECT ON v_$parameter TO &&dbusername;
GRANT SELECT ON v_$archive_dest TO &&dbusername;
GRANT SELECT ON v_$system_parameter TO &&dbusername;
GRANT SELECT ON gv_$system_parameter TO &&dbusername;



