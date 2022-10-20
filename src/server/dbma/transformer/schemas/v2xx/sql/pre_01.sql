/* 
 # Copyright 2022 Google LLC
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     https://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 */
-- name: no-process-01-drop_all_objects#
-- Drop all objects in the in-memory duckdb engine
drop table if exists AWRHISTCMDTYPES;


drop table if exists AWRHISTOSSTAT;


drop table if exists AWRHISTSYSMETRICHIST;


drop table if exists AWRHISTSYSMETRICSUMM;


drop table if exists AWRSNAPDETAILS;


drop table if exists COMPRESSBYTYPE;


drop table if exists CPUCORESUSAGE;


drop table if exists DATAGUARD;


drop table if exists DATATYPES;


drop table if exists DBAHISTSYSSTAT;


drop table if exists DBAHISTSYSTIMEMODEL;


drop table if exists DBFEATURES;


drop table if exists DBHWMARKSTATISTICS;


drop table if exists DBINSTANCES;


drop table if exists DBLINKS;


drop table if exists DBOBJECTS;


drop table if exists DBPARAMETERS;


drop table if exists DBSUMMARY;


drop table if exists EXTTAB;


drop table if exists IDXPERTABLE;


drop table if exists INDEXESTYPES;


drop table if exists IOEVENTS;


drop table if exists IOFUNCTION;


drop table if exists OPKEYLOG;


drop table if exists PDBSINFO;


drop table if exists PDBSOPENMODE;


drop table if exists SOURCECODE;


drop table if exists SOURCECONN;


drop table if exists SQLSTATS;


drop table if exists TABLESNOPK;


drop table if exists USEDSPACEDETAILS;


drop table if exists USRSEGATT;


drop table if exists awrhistosstat_rs;


drop table if exists awrhistosstat_rs_metrics;


drop table if exists awrhistsysmetrichist_rs;


drop table if exists awrhistsysmetrichist_rs_awrhistosstat_rs;


drop table if exists dbmigration_base;


drop table if exists dbmigration_details;


drop table if exists dbsizing_facts;


drop table if exists dbsizing_facts_orig;


drop table if exists dbsizing_summary;


drop table if exists optimusconfig_bms_machinesizes;


drop table if exists optimusconfig_network_to_gcp;


drop table if exists t_ds_cpu_calc;


drop table if exists T_DS_BMS_sizing;


drop table if exists T_DS_Database_Metrics;


drop table if exists vsysstat_columnar;