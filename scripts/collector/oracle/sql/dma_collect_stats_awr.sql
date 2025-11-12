--
-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License").
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
--column t_sqlstats_dir   new_value  s_sqlstats_dir noprint
--column t_sqlstats_ver   new_value  s_sqlstats_ver noprint

--SELECT  CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN 'sqlstats111.sql' ELSE 'sqlstats.sql' END as t_sqlstats_ver,
--        CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN 'sql/extracts/awr/' ELSE 'sql/extracts/awr/' END as t_sqlstats_dir
--FROM DUAL;

spool &outputdir./dma__awrsnapdetails__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|MIN_SNAP_ID|MAX_SNAP_ID|MIN_BEGIN_INTERVAL_TIME|MAX_BEGIN_INTERVAL_TIME|CNT|SUM_SNAPS_DIFF_SECS|AVG_SNAPS_DIFF_SECS|MEDIAN_SNAPS_DIFF_SECS|MODE_SNAPS_DIFF_SECS|MIN_SNAPS_DIFF_SECS|MAX_SNAPS_DIFF_SECS|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/awrsnapdetails.sql
spool off


--spool &outputdir./dma__awrhistcmdtypes__&s_tag.
--prompt PKEY|CON_ID|HH|COMMAND_TYPE|CNT|AVG_BUFFER_GETS|AVG_ELASPED_TIME|AVG_ROWS_PROCESSED|AVG_EXECUTIONS|AVG_CPU_TIME|AVG_IOWAIT|AVG_CLWAIT|AVG_APWAIT|AVG_CCWAIT|AVG_PLSEXEC_TIME|COMMAND_NAME|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/awr/awrhistcmdtypes.sql
--spool off


spool &outputdir./dma__awrhistosstat__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|HH|STAT_NAME|HH24_TOTAL_SECS|CUMULATIVE_VALUE|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|PERCENTILE_95|AVERAGED_PEAK|MIN_VALUE|MAX_VALUE|SUM_VALUE|COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/awrhistosstat.sql
spool off


spool &outputdir./dma__awrhistsysmetrichist__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|METRIC_NAME|METRIC_UNIT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERCENTILE_95|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/awrhistsysmetrichist.sql
spool off


spool &outputdir./dma__dbahistsysstat__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|STAT_NAME|CNT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERCENTILE_95|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/dbahistsysstat.sql
spool off


spool &outputdir./dma__dbahistsystimemodel__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|STAT_NAME|CNT|AVG_VALUE|MODE_VALUE|MEDIAN_VALUE|MIN_VALUE|MAX_VALUE|SUM_VALUE|PERCENTILE_95|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/dbahistsystimemodel.sql
spool off


--spool &outputdir./dma__ioevents__&s_tag.
--prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|WAIT_CLASS|EVENT_NAME|TOT_WAITS_DELTA_VALUE_P95|TOT_TOUT_DELTA_VALUE_P95|TIME_WA_US_DELTA_VALUE_P95|TOT_WAITS_DELTA_VALUE_P100|TOT_TOUT_DELTA_VALUE_P100|TIME_WA_US_DELTA_VALUE_P100|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/awr/ioevents.sql
--spool off

--spool &outputdir./dma__iofunction__&s_tag.
--prompt PKEY|DBID|INSTANCE_NUMBER|HOUR|FUNCTION_NAME|SM_READ_MB_DELTA_VALUE_P95|SM_WRITE_MB_DELTA_VALUE_P95|SM_READ_RQ_DELTA_VALUE_P95|SM_WRITE_RQ_DELTA_VALUE_P95|LG_READ_MB_DELTA_VALUE_P95|LG_WRITE_MB_DELTA_VALUE_P95|LG_READ_RQ_DELTA_VALUE_P95|LG_WRITE_RQ_DELTA_VALUE_P95|NO_IOWAIT_DELTA_VALUE_P95|TOT_WATIME_DELTA_VALUE_P95|TOTAL_READS_MB_P95|TOTAL_READS_REQ_P95|TOTAL_WRITES_MB_P95|TOTAL_WRITE_REQ_P95|SM_READ_MB_DELTA_VALUE_P100|SM_WRITE_MB_DELTA_VALUE_P100|SM_READ_RQ_DELTA_VALUE_P100|SM_WRITE_RQ_DELTA_VALUE_P100|LG_READ_MB_DELTA_VALUE_P100|LG_WRITE_MB_DELTA_VALUE_P100|LG_READ_RQ_DELTA_VALUE_P100|LG_WRITE_RQ_DELTA_VALUE_P100|NO_IOWAIT_DELTA_VALUE_P100|TOT_WATIME_DELTA_VALUE_P100|TOTAL_READS_MB_P100|TOTAL_READS_REQ_P100|TOTAL_WRITES_MB_P100|TOTAL_WRITE_REQ_P100
--@sql/extracts/awr/&s_io_function_sql.
--spool off


spool &outputdir./dma__sourceconn__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|HO|PROGRAM|MODULE|MACHINE|COMMAND_NAME|CNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/sourceconn.sql
spool off


--spool &outputdir./dma__sqlstats__&s_tag.
--prompt PKEY|CON_ID|DBID|INSTANCE_NUMBER|FORCE_MATCHING_SIGNATURE|SQL_ID|TOTAL_EXECUTIONS|TOTAL_PX_SERVERS_EXECS|ELAPSED_TIME_TOTAL|DISK_READS_TOTAL|PHYSICAL_READ_BYTES_TOTAL|PHYSICAL_WRITE_BYTES_TOTAL|IO_OFFLOAD_ELIG_BYTES_TOTAL|IO_INTERCONNECT_BYTES_TOTAL|OPTIMIZED_PHYSICAL_READS_TOTAL|CELL_UNCOMPRESSED_BYTES_TOTAL|IO_OFFLOAD_RETURN_BYTES_TOTAL|DIRECT_WRITES_TOTAL|PERC_EXEC_FINISHED|AVG_ROWS|AVG_DISK_READS|AVG_BUFFER_GETS|AVG_CPU_TIME_US|AVG_ELAPSED_US|AVG_IOWAIT_US|AVG_CLWAIT_US|AVG_APWAIT_US|AVG_CCWAIT_US|AVG_PLSEXEC_US|AVG_JAVEXEC_US|DMA_SOURCE_ID|DMA_MANUAL_ID
--@&s_sqlstats_dir.&s_sqlstats_ver.
--spool off

spool &outputdir./dma__system_metric_time_series__&s_tag.
prompt PKEY|SNAP_ID|INSTANCE_NUMBER|BEGIN_INTERVAL_TIME|SESSION_COUNT|CPU_PER_SEC|HOST_CPU_CENTISECS_PER_SEC|DATABASE_TIME_CENTISECS_PER_SEC|EXECUTIONS_PER_SEC|IO_MB_PER_SEC|IO_REQ_PER_SEC|LOGICAL_READS_PER_SEC|LOGINS_PER_SEC|NETWORK_TRAFFIC_BYTES_PER_SEC|REDO_BYTES_PER_SEC|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/dba_system_metric_time_series.sql
spool off

spool &outputdir./dma__iops_series__&s_tag.
prompt PKEY|BEGIN_INTERVAL_TIME|SNAP_ID|INSTANCE_NUMBER|READ_REQS|WRITE_REQS|READ_BYTES|WRITE_BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/iops_series.sql
spool off

spool &outputdir./dma__active_sessions_time_series__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|BEGIN_INTERVAL_TIME|SESSIONS_ON_CPU_OR_RESMGR|SESSIONS_ON_CPU|SESSIONS_ON_RES_MGR|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/active_sessions_time_series.sql
spool off

spool &outputdir./dma__os_load_time_series__&s_tag.
prompt PKEY|DBID|INSTANCE_NUMBER|BEGIN_INTERVAL_TIME|NUM_CPU_CORES|OS_LOAD|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/awr/dba_os_load_time_series.sql
spool off

