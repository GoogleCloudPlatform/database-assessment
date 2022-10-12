-- name: load_awr_hist_cmd_types!
insert into AWRHISTCMDTYPES
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_awr_hist_os_stat!
insert into AWRHISTOSSTAT
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_awr_hist_sys_metric_hist!
insert into AWRHISTSYSMETRICHIST
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_awr_hist_sys_metric_summary!
insert into AWRHISTSYSMETRICSUMM
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_awr_snap_details!
insert into AWRSNAPDETAILS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_compression_by_type!
insert into COMPRESSBYTYPE
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_cpu_core_usage!
insert into CPUCORESUSAGE
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_dataguard!
insert into DATAGUARD
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_data_types!
insert into DATATYPES
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_dba_hist_sys_stat!
insert into DBAHISTSYSSTAT
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_dba_hist_sys_time_model!
insert into DBAHISTSYSTIMEMODEL
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_features!
insert into DBFEATURES
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_high_water_stats!
insert into DBHWMARKSTATISTICS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_instances!
insert into DBINSTANCES
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_links!
insert into DBLINKS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_objects!
insert into DBOBJECTS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_parameters!
insert into DBPARAMETERS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_summary!
insert into DBSUMMARY
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_external_tables!
insert into EXTTAB
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_index_per_table!
insert into IDXPERTABLE
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_index_types!
insert into INDEXESTYPES
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_io_events!
insert into IOEVENTS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_io_function!
insert into IOFUNCTION
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_pdbs_info!
insert into PDBSINFO
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_pdbs_in_open_mode!
insert into PDBSOPENMODE
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_source_code!
insert into SOURCECODE
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_source_connections!
insert into SOURCECONN
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_sql_stats!
insert into SQLSTATS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_constraint_summary!
insert into TABLESNOPK
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_used_space_details!
insert into USEDSPACEDETAILS
select * from read_csv_auto(?, delim=?, header=True)
-- name: load_db_user_tablespace_segments!
insert into USRSEGATT
select * from read_csv_auto(?, delim=?, header=True)