/*
Copyright 2021 Google LLC

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

/*

Version: 2.0.3
Date: 2022-02-01

*/

set verify off

accept dbusername char prompt "Please enter the DB Local Username(Or CDB Username) to receive all required grants: "

grant create session to &&dbusername  container = all;
grant execute on sys.DBMS_SPACE_ADMIN to &&dbusername  container = all;
grant select on sys.v_$database to &&dbusername  container = all;
grant select on sys.v_$instance to &&dbusername  container = all;
grant select on sys.cdb_users to &&dbusername  container = all;
grant select on sys.v_$version to &&dbusername  container = all;
grant select on sys.v_$log_history to &&dbusername  container = all;
grant select on sys.v_$log to &&dbusername  container = all;
grant select on sys.v_$sgastat to &&dbusername  container = all;
grant select on sys.v_$pgastat to &&dbusername  container = all;
grant select on sys.cdb_data_files to &&dbusername  container = all;
grant select on sys.cdb_segments to &&dbusername  container = all;
grant select on sys.cdb_pdbs to &&dbusername  container = all;
grant select on sys.v_$pdbs to &&dbusername  container = all;
grant select on sys.gv_$instance to &&dbusername  container = all;
grant select on sys.cdb_tables to &&dbusername  container = all;
grant select on sys.cdb_tab_partitions to &&dbusername  container = all;
grant select on sys.cdb_tab_subpartitions to &&dbusername  container = all;
grant select on sys.cdb_tablespaces to &&dbusername  container = all;
grant select on sys.cdb_data_files to &&dbusername  container = all;
grant select on sys.cdb_free_space to &&dbusername  container = all;
grant select on sys.v_$temp_space_header to &&dbusername  container = all;
grant select on sys.gv_$parameter to &&dbusername  container = all;
grant select on sys.cdb_feature_usage_statistics to &&dbusername  container = all;
grant select on sys.dba_high_water_mark_statistics to &&dbusername  container = all;
grant select on sys.dba_cpu_usage_statistics to &&dbusername  container = all;
grant select on sys.cdb_objects to &&dbusername  container = all;
grant select on sys.cdb_source to &&dbusername  container = all;
grant select on sys.cdb_part_tables to &&dbusername  container = all;
grant select on sys.cdb_indexes to &&dbusername  container = all;
grant select on sys.cdb_tab_columns to &&dbusername  container = all;
grant select on sys.cdb_constraints to &&dbusername  container = all;
grant select on sys.aux_stats$ to &&dbusername  container = all;
grant select on sys.registry$history to &&dbusername  container = all;
grant select on sys.dba_hist_snapshot to &&dbusername  container = all;
grant select on sys.dba_hist_sysstat to &&dbusername  container = all;
grant select on sys.dba_hist_sys_time_model to &&dbusername  container = all;
grant select on sys.dba_hist_sqltext to &&dbusername  container = all;
grant select on sys.dba_hist_osstat to &&dbusername  container = all;
grant select on sys.dba_hist_sysmetric_history to &&dbusername  container = all;
grant select on sys.dba_hist_sysmetric_summary to &&dbusername  container = all;
grant select on sys.v_$diag_alert_ext to &&dbusername  container = all;
grant select on sys.cdb_services to &&dbusername  container = all;
grant select on sys.dba_hist_sqlstat to &&dbusername  container = all;
grant select on system.logstdby$skip_support to &&dbusername  container = all;
grant select on cdb_db_links to &&dbusername  container = all;
grant select on sys.dba_registry_sqlpatch to &&dbusername  container = all;
grant select on sys.dba_users to &&dbusername  container = all;
grant select on sys.dba_segments to &&dbusername  container = all;
grant select on sys.dba_tablespaces to &&dbusername  container = all;
grant select on sys.dba_free_space to &&dbusername  container = all;
grant select on sys.dba_db_links to &&dbusername  container = all;
grant select on sys.dba_feature_usage_statistics to &&dbusername  container = all;
grant select on sys.dba_objects to &&dbusername  container = all;
grant select on sys.dba_source to &&dbusername  container = all;
grant select on sys.dba_part_tables to &&dbusername  container = all;
grant select on sys.dba_indexes to &&dbusername  container = all;
grant select on sys.dba_tab_columns to &&dbusername  container = all;
grant select on sys.dba_constraints  to &&dbusername  container = all;
grant select on sys.dba_services  to &&dbusername  container = all;
grant select on sys.dba_data_files  to &&dbusername  container = all;
grant select on sys.dba_tables  to &&dbusername  container = all;
grant select on sys.dba_tab_partitions to &&dbusername  container = all;
grant select on sys.dba_tab_subpartitions to &&dbusername  container = all;
grant select on sys.nls_database_parameters to &&dbusername  container = all;
ALTER USER &&dbusername SET CONTAINER_DATA=ALL CONTAINER=CURRENT;
