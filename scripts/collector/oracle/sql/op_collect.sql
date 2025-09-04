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

set termout on pause on
SET DEFINE "&"
DEFINE dmaVersion=&1
DEFINE SQLDIR=&2
DEFINE s_statssrc=&3
DEFINE s_tag=&4
DEFINE outputdir=&5
DEFINE s_manualUniqueId=&6
DEFINE p_statsWindow=&7

DEFINE EXTRACTSDIR=&SQLDIR/extracts
DEFINE AWRDIR=sql/extracts/awr
DEFINE STATSPACKDIR=sql/extracts/statspack
DEFINE TERMOUTOFF=OFF
prompt
prompt ***********************************************************************************
prompt
prompt !!! ATTENTION !!!
prompt
@&SQLDIR/prompt_&s_statssrc.
prompt
prompt
prompt ***********************************************************************************
prompt

prompt Initializing Database Migration Assessment Collector...
prompt
BEGIN
 DBMS_SESSION.set_identifier('DMA COLLECTOR');
END;
/

set termout &TERMOUTOFF
@@op_collect_init.sql
prompt
prompt Initialization completed.

variable v_manual_unique_id            VARCHAR2(100);
-- Set manual_unique_id
BEGIN
  :v_manual_unique_id :=  chr(39) || '&s_manualUniqueId' || chr(39);
END;
/

--variable v_dma_source_id               VARCHAR2(100);
--SELECT lower(i.host_name||'_'||&s_db_unique_name||'_'||d.dbid) INTO :v_dma_source_id


prompt
prompt Collecting Database Migration Assessment data...
prompt

set termout &TERMOUTOFF
spool &outputdir./opdb__collector_runtime_env__&s_tag. APPEND
SELECT 'START TIME ' || to_char(sysdate, 'YYYY/MM/DD HH24:MI:SS') FROM DUAL;
@sql/extracts/collector_runtime_env.sql
spool off


spool &outputdir./opdb__schema_detail__&s_tag.
prompt PKEY|CON_ID|OWNER|OBJECT_NAME|OBJECT_TYPE|OBJECT_STATUS|PARTITIONED|IOT_TYPE|NESTED|TEMPORARY|SECONDARY|CLUSTERED_TABLE|OBJECT_TABLE|XML_TABLE|IS_EXTERNAL_TABLE|PARTITIONING_TYPE|SUBPARTITIONING_TYPE|PARTITION_COUNT|SUBPARTITION_COUNT|UPDATABLE|REWRITE_ENABLED|REFRESH_MODE|REFRESH_METHOD|FAST_REFRESHABLE|COMPILE_STATE|ANYDATA_COL_COUNT|BFILE_COL_COUNT|BINARY_DOUBLE_COL_COUNT|BINARY_FLOAT_COL_COUNT|BLOB_COL_COUNT|CFILE_COL_COUNT|CHAR_COL_COUNT|CLOB_COL_COUNT|DATE_COL_COUNT|FLOAT_COL_COUNT|INTERVAL_DAY_TO_SECOND_COL_COU|INTERVAL_YEAR_TO_MONTH_COL_COU|JSON_COL_COUNT|LONG_RAW_COL_COUNT|LONG_COL_COUNT|MLSLABEL_COL_COUNT|NCHAR_VARYING_COL_COUNT|NCHAR_COL_COUNT|NCLOB_COL_COUNT|NUMBER_COL_COUNT|NVARCHAR2_COL_COUNT|RAW_COL_COUNT|ROWID_COL_COUNT|SPATIAL_COL_COUNT|TIME_WITH_TIME_ZONE_COL_COUNT|TIME_COL_COUNT|TIMESTAMP_WITH_LOCAL_TIME_Z_CO|TIMESTAMP_WITH_TIME_ZONE_COL_C|TIMESTAMP_COL_COUNT|UROWID_COL_COUNT|VARCHAR_COL_COUNT|VARCHAR2_COL_COUNT|XMLTYPE_COL_COUNT|UNDEFINED_COL_COUNT|USER_DEFINED_COL_COUNT|SOURCE_SUM_NR_LINES|SOURCE_SUM_NR_LINES_W_UTL|SOURCE_SUM_NR_LINES_W_DBMS|SOURCE_COUNT_EXEC_IM|SOURCE_COUNT_DBMS_SQL|SOURCE_SUM_NR_LINES_W_DBMS_UTL|SOURCE_TRIGGER_TYPE|SOURCE_TRIGGERING_EVENT|SOURCE_BASE_OBJECT_TYPE|INDEX_TYPE|INDEX_UNIQUENESS|INDEX_COMPRESSION|INDEX_PARTITIONED|INDEX_TEMPORARY|INDEX_SECONDARY|INDEX_VISIBILITY|INDEX_JOIN_INDEX|INDEX_CUSTOM_INDEX_TYPE|INDEX_TABLE_NAME|SEGMENT_MB|SEGMENTS_IN_SYSTEM_TS|PRIMARY_KEY_COUNT|UNIQUE_CONS_COUNT|CHECK_CONS_COUNT|FOREIGN_KEY_CONS_COUNT|VIEW_CHECK_CONS_COUNT|VIEW_READ_ONLY_COUNT|HASH_EXPR_COUNT|REFCOLCONS|SUPPLEMENTAL_LOGGING_COUNT|NOT_NULL_CONS_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/schema_detail.sql
spool off


spool &outputdir./opdb__archlogs__&s_tag.
prompt PKEY|LOG_START_DATE|HO|THREAD_NUM|DEST_ID|CNT|MBYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/archlogs.sql
spool off


spool &outputdir./opdb__backups__&s_tag.
prompt PKEY|BACKUP_START_DATE|CON_ID|INPUT_TYPE|ELAPSED_SECONDS|MBYTES_IN|MBYTES_OUT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/&s_ora9ind.backups.sql
spool off


spool &outputdir./opdb__db_features__&s_tag.
prompt PKEY|CON_ID|NAME|CURRE|DETECTED_USAGES|TOTAL_SAMPLES|FIRST_USAGE|LAST_USAGE|AUX_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/&s_ora9ind.dbfeatures.sql
spool off


spool &outputdir./opdb__db_hwmark_statistics__&s_tag.
prompt PKEY|DESCRIPTION|HIGHWATER|LAST_VALUE|CON_ID|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/&s_ora9ind.dbhwmarkstatistics.sql
spool off


spool &outputdir./opdb__db_instances__&s_tag.
prompt PKEY|INST_ID|INSTANCE_NAME|HOST_NAME|VERSION|STATUS|DATABASE_STATUS|INSTANCE_ROLE|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/dbinstances.sql
spool off


spool &outputdir./opdb__db_parameters__&s_tag.
prompt PKEY|INST_ID|CON_ID|NAME|VALUE|DEFAULT_VALUE|ISDEFAULT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/dbparameters.sql
spool off


spool &outputdir./opdb__db_summary__&s_tag.
prompt PKEY|DBID|DB_NAME|CDB|DB_VERSION|DB_FULLVERSION|LOG_MODE|FORCE_LOGGING|RAC_DBINSTANCES|CHARACTERSET|PLATFORM_NAME|STARTUP_TIME|USER_SCHEMAS|BUFFER_CACHE_MB|SHARED_POOL_MB|TOTAL_PGA_ALLOCATED_MB|DB_SIZE_ALLOCATED_GB|DB_SIZE_IN_USE_GB|DB_LONG_SIZE_GB|DG_DATABASE_ROLE|DG_PROTECTION_MODE|DG_PROTECTION_LEVEL|DB_SIZE_TEMP_ALLOCATED_GB|DB_SIZE_REDO_ALLOCATED_GB|EBS_OWNER|SIEBEL_OWNER|PSFT_OWNER|RDS_FLAG|OCI_AUTONOMOUS_FLAG|DBMS_CLOUD_PKG_INSTALLED|APEX_INSTALLED|SAP_OWNER|DB_UNIQUE_NAME|DG_STANDBY_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/dbsummary.sql
spool off


spool &outputdir./opdb__op_key_log__&s_tag.
prompt PKEY|OPSCRI|DB_|HOSTNAME|DB_NAME|INSTANCE_NAME|COLLECTION_T|DB_ID|C|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/opkeylog.sql
spool off


@sql/&s_tenancy.

@sql/op_collect_stats_&s_statssrc.

spool &outputdir./opdb__db_lob_sizing__&s_tag.
prompt PKEY|CON_ID|OWNER|TABLE_NAME|TABLE_NUM_ROWS|TAB|PARTITIONED|COLUMN_NAME|DATA_TYPE|TABLE_PARTITION_NAME|TABLE_PARTITION_SEG_CREATED|PARTITION_NUM_ROWS|LOB_PARTITION_NAME|LOB_PARTITION_SEG_CREATED|SUBPARTITION_COUNT|TABLE_SUBPARTITION_NAME|TABLE_SUBPARTITION_CREATED|SUBPARTITION_NUM_ROWS|LOB_SUBPARTITION_NAME|LOB_SUBPARTITION_SEG_CREATED|LOB_SEG_NAME|SEG_NAME|SEG_PARTITION_NAME|LOB_COMPRESSION|LOB_PARTITION_COMPRESSION|LOB_SUBPARTITION_COMPRESSION|LOB_DEDUPLICATION|LOB_PARTITION_DEDUPLICATION|LOB_SUBPARTITION_DEDUPLICATION|SEG_BYTES|TABLE_AVG_LOB_BYTES|PARTITION_AVG_LOB_BYTES|SUBPARTITION_AVG_LOB_BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/lobsizing.sql
spool off


spool &outputdir./opdb__eoj__&s_tag.
prompt END_OF_DMA_COLLECTION
@sql/extracts/eoj.sql
spool off


spool  &outputdir./opdb__collector_runtime_env__&s_tag. APPEND
SELECT 'END TIME   ' || to_char(sysdate, 'YYYY/MM/DD HH24:MI:SS') FROM DUAL;
spool off

set termout on
prompt Step completed.
prompt
prompt Database Migration Assessment data successfully extracted.
prompt
exit
