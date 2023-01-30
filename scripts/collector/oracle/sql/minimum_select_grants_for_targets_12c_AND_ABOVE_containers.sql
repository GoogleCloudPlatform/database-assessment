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

/* This script grants privileges that are needed only when extracting from a container database. */
/* It will be called by the grants_wrapper process.                                              */


grant select on sys.cdb_constraints to &&dbusername;
grant select on sys.cdb_cpu_usage_statistics to &&dbusername;
grant select on sys.cdb_data_files to &&dbusername;
grant select on sys.cdb_db_links to &&dbusername;
grant select on sys.cdb_external_tables to &&dbusername;
grant select on sys.cdb_feature_usage_statistics to &&dbusername;
grant select on sys.cdb_free_space to &&dbusername;
grant select on sys.cdb_high_water_mark_statistics to &&dbusername;
grant select on sys.cdb_hist_active_sess_history to &&dbusername;
grant select on sys.cdb_hist_iostat_function to &&dbusername;
grant select on sys.cdb_hist_osstat to &&dbusername;
grant select on sys.cdb_hist_snapshot to &&dbusername;
grant select on sys.cdb_hist_sqlstat to &&dbusername;
grant select on sys.cdb_hist_sqltext to &&dbusername;
grant select on sys.cdb_hist_sys_time_model to &&dbusername;
grant select on sys.cdb_hist_sysmetric_history to &&dbusername;
grant select on sys.cdb_hist_sysmetric_summary to &&dbusername;
grant select on sys.cdb_hist_sysstat to &&dbusername;
grant select on sys.cdb_hist_system_event to &&dbusername;
grant select on sys.cdb_indexes to &&dbusername;
grant select on sys.cdb_lob_partitions to &&dbusername;
grant select on sys.cdb_lob_subpartitions to &&dbusername;
grant select on sys.cdb_lobs to &&dbusername;
grant select on sys.cdb_mviews to &&dbusername;
grant select on sys.cdb_object_tables  to &&dbusername;
grant select on sys.cdb_object_tables to &&dbusername;
grant select on sys.cdb_objects to &&dbusername;
grant select on sys.cdb_part_tables to &&dbusername;
grant select on sys.cdb_pdbs to &&dbusername;
grant select on sys.cdb_segments to &&dbusername;
grant select on sys.cdb_services to &&dbusername;
grant select on sys.cdb_source to &&dbusername;
grant select on sys.cdb_synonyms to &&dbusername;
grant select on sys.cdb_tab_cols to &&dbusername;
grant select on sys.cdb_tab_columns to &&dbusername;
grant select on sys.cdb_tab_partitions to &&dbusername;
grant select on sys.cdb_tab_subpartitions to &&dbusername;
grant select on sys.cdb_tables to &&dbusername;
grant select on sys.cdb_tablespaces to &&dbusername;
grant select on sys.cdb_temp_files to &&dbusername;
grant select on sys.cdb_triggers to &&dbusername;
grant select on sys.cdb_users to &&dbusername;
grant select on sys.cdb_views to  &&dbusername;
grant select on sys.cdb_xml_tables  to &&dbusername;
grant select on sys.cdb_xml_tables to &&dbusername;

alter user  &&dbusername set container_data=all container = current;

