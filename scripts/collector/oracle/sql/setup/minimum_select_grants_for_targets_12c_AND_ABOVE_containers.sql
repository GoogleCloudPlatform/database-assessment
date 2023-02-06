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

/* This script grants privileges that are needed only when extracting from a container database. */
/* It will be called by the grants_wrapper process.                                              */
set feedback on
prompt Granting privileges for 12+ container views
set feedback off

set termout on
set echo on
set feedback on
set verify on

GRANT SELECT ON sys.cdb_constraints TO &&dbusername;
GRANT SELECT ON sys.cdb_cpu_usage_statistics TO &&dbusername;
GRANT SELECT ON sys.cdb_data_files TO &&dbusername;
GRANT SELECT ON sys.cdb_db_links TO &&dbusername;
GRANT SELECT ON sys.cdb_external_tables TO &&dbusername;
GRANT SELECT ON sys.cdb_feature_usage_statistics TO &&dbusername;
GRANT SELECT ON sys.cdb_free_space TO &&dbusername;
GRANT SELECT ON sys.cdb_high_water_mark_statistics TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_active_sess_history TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_iostat_function TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_osstat TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_snapshot TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_sqlstat TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_sqltext TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_sys_time_model TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_sysmetric_history TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_sysmetric_summary TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_sysstat TO &&dbusername;
GRANT SELECT ON sys.cdb_hist_system_event TO &&dbusername;
GRANT SELECT ON sys.cdb_indexes TO &&dbusername;
GRANT SELECT ON sys.cdb_lob_partitions TO &&dbusername;
GRANT SELECT ON sys.cdb_lob_subpartitions TO &&dbusername;
GRANT SELECT ON sys.cdb_lobs TO &&dbusername;
GRANT SELECT ON sys.cdb_mviews TO &&dbusername;
GRANT SELECT ON sys.cdb_object_tables TO &&dbusername;
GRANT SELECT ON sys.cdb_object_tables TO &&dbusername;
GRANT SELECT ON sys.cdb_objects TO &&dbusername;
GRANT SELECT ON sys.cdb_part_tables TO &&dbusername;
GRANT SELECT ON sys.cdb_pdbs TO &&dbusername;
GRANT SELECT ON sys.cdb_segments TO &&dbusername;
GRANT SELECT ON sys.cdb_services TO &&dbusername;
GRANT SELECT ON sys.cdb_source TO &&dbusername;
GRANT SELECT ON sys.cdb_synonyms TO &&dbusername;
GRANT SELECT ON sys.cdb_tab_cols TO &&dbusername;
GRANT SELECT ON sys.cdb_tab_columns TO &&dbusername;
GRANT SELECT ON sys.cdb_tab_partitions TO &&dbusername;
GRANT SELECT ON sys.cdb_tab_subpartitions TO &&dbusername;
GRANT SELECT ON sys.cdb_tables TO &&dbusername;
GRANT SELECT ON sys.cdb_tablespaces TO &&dbusername;
GRANT SELECT ON sys.cdb_temp_files TO &&dbusername;
GRANT SELECT ON sys.cdb_triggers TO &&dbusername;
GRANT SELECT ON sys.cdb_users TO &&dbusername;
GRANT SELECT ON sys.cdb_views TO &&dbusername;
GRANT SELECT ON sys.cdb_xml_tables TO &&dbusername;
GRANT SELECT ON sys.cdb_xml_tables TO &&dbusername;
GRANT SELECT ON sys.container$ TO &&dbusername;
GRANT SELECT ON sys.obj$ TO &&dbusername;

ALTER USER &&dbusername SET CONTAINER_DATA=all CONTAINER=current;

