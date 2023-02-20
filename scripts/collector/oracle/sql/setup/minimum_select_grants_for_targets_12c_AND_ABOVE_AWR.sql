/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed TO in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

set feedback on
prompt Granting privileges for 12g+ non-container views
set feedback off

set verify off

--accept dbusername char prompt "Please enter the DB Local Username(Or CDB Username) TO receive all required grants: "
GRANT ALTER SESSION TO &&dbusername;
GRANT CREATE SESSION TO &&dbusername;

GRANT SELECT ON sys.aux_stats$ TO &&dbusername;
GRANT SELECT ON sys.dba_constraints TO &&dbusername;
GRANT SELECT ON sys.dba_cpu_usage_statistics TO &&dbusername;
GRANT SELECT ON sys.dba_data_files TO &&dbusername;
GRANT SELECT ON sys.dba_db_links TO &&dbusername;
GRANT SELECT ON sys.dba_external_tables TO &&dbusername;
GRANT SELECT ON sys.dba_feature_usage_statistics TO &&dbusername;
GRANT SELECT ON sys.dba_free_space TO &&dbusername;
GRANT SELECT ON sys.dba_high_water_mark_statistics TO &&dbusername;
GRANT SELECT ON sys.dba_hist_active_sess_history TO &&dbusername;
GRANT SELECT ON sys.dba_hist_iostat_function TO &&dbusername;
GRANT SELECT ON sys.dba_hist_osstat TO &&dbusername;
GRANT SELECT ON sys.dba_hist_snapshot TO &&dbusername;
GRANT SELECT ON sys.dba_hist_sqlstat TO &&dbusername;
GRANT SELECT ON sys.dba_hist_sqltext TO &&dbusername;
GRANT SELECT ON sys.dba_hist_sys_time_model TO &&dbusername;
GRANT SELECT ON sys.dba_hist_sysmetric_history TO &&dbusername;
GRANT SELECT ON sys.dba_hist_sysmetric_summary TO &&dbusername;
GRANT SELECT ON sys.dba_hist_sysstat TO &&dbusername;
GRANT SELECT ON sys.dba_hist_system_event TO &&dbusername;
GRANT SELECT ON sys.dba_indexes TO &&dbusername;
GRANT SELECT ON sys.dba_lob_partitions TO &&dbusername;
GRANT SELECT ON sys.dba_lob_subpartitions TO &&dbusername;
GRANT SELECT ON sys.dba_lobs TO &&dbusername;
GRANT SELECT ON sys.dba_mviews TO &&dbusername;
GRANT SELECT ON sys.dba_object_tables TO &&dbusername;
GRANT SELECT ON sys.dba_objects TO &&dbusername;
GRANT SELECT ON sys.dba_part_tables TO &&dbusername;
GRANT SELECT ON sys.dba_registry_sqlpatch TO &&dbusername;
GRANT SELECT ON sys.dba_segments TO &&dbusername;
GRANT SELECT ON sys.dba_services TO &&dbusername;
GRANT SELECT ON sys.dba_source TO &&dbusername;
GRANT SELECT ON sys.dba_synonyms TO &&dbusername;
GRANT SELECT ON sys.dba_tab_cols TO &&dbusername;
GRANT SELECT ON sys.dba_tab_columns TO &&dbusername;
GRANT SELECT ON sys.dba_tab_partitions TO &&dbusername;
GRANT SELECT ON sys.dba_tab_subpartitions TO &&dbusername;
GRANT SELECT ON sys.dba_tables TO &&dbusername;
GRANT SELECT ON sys.dba_tablespaces TO &&dbusername;
GRANT SELECT ON sys.dba_temp_files TO &&dbusername;
GRANT SELECT ON sys.dba_triggers TO &&dbusername;
GRANT SELECT ON sys.dba_users TO &&dbusername;
GRANT SELECT ON sys.dba_views TO &&dbusername;
GRANT SELECT ON sys.dba_xml_tables TO &&dbusername;
GRANT SELECT ON sys.gv_$archive_dest TO &&dbusername;
GRANT SELECT ON sys.gv_$archived_log TO &&dbusername;
GRANT SELECT ON sys.gv_$instance TO &&dbusername;
GRANT SELECT ON sys.gv_$parameter TO &&dbusername;
GRANT SELECT ON sys.gv_$pdbs TO &&dbusername;
GRANT SELECT ON sys.gv_$pgastat TO &&dbusername;
GRANT SELECT ON sys.gv_$process TO &&dbusername;
GRANT SELECT ON sys.gv_$sgastat TO &&dbusername;
GRANT SELECT ON sys.gv_$system_parameter TO &&dbusername;
GRANT SELECT ON sys.nls_database_parameters TO &&dbusername;
GRANT SELECT ON sys.registry$history TO &&dbusername;
GRANT SELECT ON sys.v_$sqlcommand TO &&dbusername;
GRANT SELECT ON sys.v_$database TO &&dbusername;
GRANT SELECT ON sys.v_$instance TO &&dbusername;
GRANT SELECT ON sys.v_$log TO &&dbusername;
GRANT SELECT ON sys.v_$log_history TO &&dbusername;
GRANT SELECT ON sys.v_$logfile TO &&dbusername;
GRANT SELECT ON sys.v_$parameter TO &&dbusername;
GRANT SELECT ON sys.v_$pdbs TO &&dbusername;
GRANT SELECT ON sys.v_$pgastat TO &&dbusername;
GRANT SELECT ON sys.v_$rman_backup_job_details TO &&dbusername;
GRANT SELECT ON sys.v_$sgastat TO &&dbusername;
GRANT SELECT ON sys.v_$system_parameter TO &&dbusername;
GRANT SELECT ON sys.v_$temp_space_header TO &&dbusername;
GRANT SELECT ON sys.v_$version TO &&dbusername;
GRANT SELECT ON system.logstdby$skip_support TO &&dbusername;

GRANT SELECT ON sys.cdb_tab_columns TO &&dbusername;
-- This one is ok TO fail if umf is not installed and configured
--Prompt It is not an error if this grant fails due TO dbms_umf not being installed and configured.  It is used only when extracting from a physical standby.
--grant execute on sys.dbms_umf TO &&dbusername;


