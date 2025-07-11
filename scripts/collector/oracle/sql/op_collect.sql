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

variable v_dma_source_id               VARCHAR2(100);
SELECT lower(i.host_name||'_'||&s_db_unique_name||'_'||d.dbid) INTO :v_dma_source_id


prompt
prompt Collecting Database Migration Assessment data...
prompt

spool &outputdir./opdb__schemadetail__&s_tag.
@sql/extracts/schema_detail_hdr.sql
@sql/extracts/schema_detail.sql
spool off

set termout &TERMOUTOFF
spool &outputdir./opdb__defines__&s_tag.
@sql/extracts/defines.sql
spool off


--spool &outputdir./opdb__archlogs__&s_tag.
--prompt PKEY|LOG_START_DATE|HO|THREAD_NUM|DEST_ID|CNT|MBYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/archlogs.sql
--spool off


--spool &outputdir./opdb__users__&s_tag.
--prompt PKEY|CON_ID|USERNAME|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/users.sql
--spool off


--spool &outputdir./opdb__backups__&s_tag.
--prompt PKEY|BACKUP_START_DATE|CON_ID|INPUT_TYPE|ELAPSED_SECONDS|MBYTES_IN|MBYTES_OUT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/&s_ora9ind.backups.sql
--spool off


--spool &outputdir./opdb__columntypes__&s_tag.
--prompt PKEY|CON_ID|OWNER|TABLE_NAME|ANYDATA_COL_COUNT|BFILE_COL_COUNT|BINARY_DOUBLE_COL_COUNT|BINARY_FLOAT_COL_COUNT|BLOB_COL_COUNT|CFILE_COL_COUNT|CHAR_COL_COUNT|CLOB_COL_COUNT|DATE_COL_COUNT|FLOAT_COL_COUNT|INTERVAL_DAY_TO_SECOND_COL_COUNT|INTERVAL_YEAR_TO_MONTH_COL_COUNT|JSON_COL_COUNT|LONG_RAW_COL_COUNT|LONG_COL_COUNT|MLSLABEL_COL_COUNT|NCHAR_VARYING_COL_COUNT|NCHAR_COL_COUNT|NCLOB_COL_COUNT|NUMBER_COL_COUNT|NVARCHAR2_COL_COUNT|RAW_COL_COUNT|ROWID_COL_COUNT|SPATIAL_COL_COUNT|TIME_WITH_TIME_ZONE_COL_COUNT|TIME_COL_COUNT|TIMESTAMP_WITH_LOCAL_TIME_Z_COUNT|TIMESTAMP_WITH_TIME_ZONE_COL_COUNT|TIMESTAMP_COL_COUNT|UROWID_COL_COUNT|VARCHAR_COL_COUNT|VARCHAR2_COL_COUNT|XMLTYPE_COL_COUNT|UNDEFINED_COL_COUNT|USER_DEFINED_COL_COUNT|BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/columntypes.sql
--spool off


spool &outputdir./opdb__compressbytype__&s_tag.
@sql/extracts/compressbytype.sql
spool off


--spool &outputdir./opdb__cpucoresusage__&s_tag.
--prompt PKEY|DT|CPU_COUNT|CPU_CORE_COUNT|CPU_SOCKET_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/&s_ora9ind.cpucoresusage.sql
--spool off


--spool &outputdir./opdb__dataguard__&s_tag.
--prompt PKEY|CON_ID|INST_ID|LOG_ARCHIVE_CONFIG|DEST_ID|DEST_NAME|DESTINATION|STATUS|TARGET|SCHEDULE|REGISTER|ALTERNATE|TRANSMIT_MODE|AFFIRM|VALID_ROLE|VERIFY|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/dataguard.sql
--spool off


spool &outputdir./opdb__datatypes__&s_tag.
prompt PKEY|CON_ID|OWNER|DATA_TYPE|CNT|DATA_LENGTH|DATA_PRECISION|DATA_SCALE|AVG_COL_LEN|DISTINCT_TABLE_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/datatypes.sql
spool off


spool &outputdir./opdb__dbfeatures__&s_tag.
prompt PKEY|CON_ID|NAME|CURRE|DETECTED_USAGES|TOTAL_SAMPLES|FIRST_USAGE|LAST_USAGE|AUX_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/&s_ora9ind.dbfeatures.sql
spool off


--spool &outputdir./opdb__dbhwmarkstatistics__&s_tag.
--prompt PKEY|DESCRIPTION|HIGHWATER|LAST_VALUE|CON_ID|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/&s_ora9ind.dbhwmarkstatistics.sql
--spool off


spool &outputdir./opdb__dbinstances__&s_tag.
prompt PKEY|INST_ID|INSTANCE_NAME|HOST_NAME|VERSION|STATUS|DATABASE_STATUS|INSTANCE_ROLE|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/dbinstances.sql
spool off


--spool &outputdir./opdb__dblinks__&s_tag.
--prompt PKEY|CON_ID|OWNER|COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/dblinks.sql
--spool off


--spool &outputdir./opdb__dbobjects__&s_tag.
--prompt PKEY|CON_ID|OWNER|OBJECT_TYPE|EDITIONABLE|COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/dbobjects.sql
--spool off


--spool &outputdir./opdb__dbobjectnames__&s_tag.
--prompt PKEY|CON_ID|OWNER|OBJECT_NAME|OBJECT_TYPE|EDITIONABLE|LINES|STATUS|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/dbobjectnames.sql
--spool off


spool &outputdir./opdb__dbparameters__&s_tag.
prompt PKEY|INST_ID|CON_ID|NAME|VALUE|DEFAULT_VALUE|ISDEFAULT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/dbparameters.sql
spool off


spool &outputdir./opdb__dbsummary__&s_tag.
prompt PKEY|DBID|DB_NAME|CDB|DB_VERSION|DB_FULLVERSION|LOG_MODE|FORCE_LOGGING|REDO_GB_PER_DAY|RAC_DBINSTANCES|CHARACTERSET|PLATFORM_NAME|STARTUP_TIME|USER_SCHEMAS|BUFFER_CACHE_MB|SHARED_POOL_MB|TOTAL_PGA_ALLOCATED_MB|DB_SIZE_ALLOCATED_GB|DB_SIZE_IN_USE_GB|DB_LONG_SIZE_GB|DG_DATABASE_ROLE|DG_PROTECTION_MODE|DG_PROTECTION_LEVEL|DB_SIZE_TEMP_ALLOCATED_GB|DB_SIZE_REDO_ALLOCATED_GB|EBS_OWNER|SIEBEL_OWNER|PSFT_OWNER|RDS_FLAG|OCI_AUTONOMOUS_FLAG|DBMS_CLOUD_PKG_INSTALLED|APEX_INSTALLED|SAP_OWNER|DB_UNIQUE_NAME|DG_STANDBY_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/dbsummary.sql
spool off


--spool &outputdir./opdb__exttab__&s_tag.
--prompt PKEY|CON_ID|OWNER|TABLE_NAME|TYP|TYPE_NAME|DEF|DEFAULT_DIRECTORY_NAME|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/exttab.sql
--spool off


spool &outputdir./opdb__idxpertable__&s_tag.
prompt PKEY|CON_ID|TAB_COUNT|IDX_CNT|IDX_PERC|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/idxpertable.sql
spool off


--spool &outputdir./opdb__indextypes__&s_tag.
--prompt PKEY|CON_ID|OWNER|INDEX_TYPE|UNIQUENESS|COMPRESSION|PARTITIONED|TEMPORARY|SECONDARY|VISIBILITY|JOIN_INDEX|CUSTOM_INDEX_TYPE|CNT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/indextypes.sql
--spool off


spool &outputdir./opdb__indextypedtl__&s_tag.
prompt PKEY|CON_ID|OWNER|INDEX_TYPE|UNIQUENESS|COMPRESSION|PARTITIONED|TEMPORARY|SECONDARY|VISIBILITY|JOIN_INDEX|CUSTOM_INDEX_TYPE|TABLE_NAME|INDEX_NAME|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/indextypedtl.sql
spool off


--spool &outputdir./opdb__mviewtypes__&s_tag.
--prompt PKEY|CON_ID|OWNER|UPDATABLE|REWRITE_ENABLED|REFRESH_MODE|REFRESH_METHOD|FAST_REFRESHABLE|COMPILE_STATE|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/mviewtypes.sql
--spool off


spool &outputdir./opdb__opkeylog__&s_tag.
prompt PKEY|OPSCRI|DB_|HOSTNAME|DB_NAME|INSTANCE_NAME|COLLECTION_T|DB_ID|C|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/opkeylog.sql
spool off


--spool &outputdir./opdb__sourcecode__&s_tag.
--prompt PKEY|CON_ID|OWNER|TYPE|SUM_NR_LINES|QT_OBJS|SUM_NR_LINES_W_UTL|SUM_NR_LINES_W_DBMS|COUNT_EXEC_IM|COUNT_DBMS_SQL|SUM_NR_LINES_W_DBMS_UTL|SUM_COUNT_TOTAL|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/sourcecode.sql
--spool off


--spool &outputdir./opdb__dtlsourcecode__&s_tag.
--prompt PKEY|CON_ID|OWNER|NAME|TYPE|SUM_NR_LINES|QT_OBJS|SUM_NR_LINES_W_UTL|SUM_NR_LINES_W_DBMS|COUNT_EXEC_IM|COUNT_DBMS_SQL|SUM_NR_LINES_W_DBMS_UTL|SUM_COUNT_TOTAL|TRIGGER_TYPE|TRIGGERING_EVENT|BASE_OBJECT_TYPE|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/dtlsourcecode.sql
--spool off


--spool &outputdir./opdb__tablesnopk__&s_tag.
--prompt PKEY|CON_ID|OWNER|PK|UK|CK|RI|VWCK|VWRO|HASHEXPR|SUPLOG|NUM_TABLES|TOTAL_CONS|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/tablesnopk.sql
--spool off


spool &outputdir./opdb__tableconstraints__&s_tag.
prompt PKEY|CON_ID|OWNER|TABLE_NAME|PK|UK|CK|RI|VWCK|VWRO|HASHEXPR|SUPLOG|TOTAL_CONS|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/tableconstraints.sql
spool off


--spool &outputdir./opdb__tabletypes__&s_tag.
--prompt PKEY|CON_ID|OWNER|PAR|IOT_TYPE|NESTED|TEMPORARY|SECONDARY|CLUSTERED_TABLE|TABLE_COUNT|OBJECT_TABLE|XML_TABLE|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/tabletypes.sql
--spool off


--spool &outputdir./opdb__tabletypedtl__&s_tag.
--prompt PKEY|CON_ID|OWNER|TABLE_NAME|PAR|IOT_TYPE|NESTED|TEMPORARY|SECONDARY|CLUSTERED_TABLE|OBJECT_TABLE|XML_TABLE|PARTITIONING_TYPE|SUBPARTITIONING_TYPE|PARTITION_COUNT|SUBPARTITION_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/tabletypedtl.sql
--spool off


--spool &outputdir./opdb__triggers__&s_tag.
--prompt PKEY|CON_ID|OWNER|TRIGGER_TYPE|TRIGGERING_EVENT|BASE_OBJECT_TYPE|TRIGGER_COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
--@sql/extracts/triggers.sql
--spool off


spool &outputdir./opdb__usedspacedetails__&s_tag.
prompt PKEY|CON_ID|OWNER|SEGMENT_TYPE|GB|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/usedspacedetails.sql
spool off


spool &outputdir./opdb__usrsegatt__&s_tag.
prompt PKEY|CON_ID|OWNER|SEGMENT_NAME|SEGMENT_TYPE|TABLESPACE_NAME|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/usrsegatt.sql
spool off


@sql/&s_tenancy.

@sql/op_collect_stats_&s_statssrc.

spool &outputdir./opdb__lobsizing__&s_tag.
prompt PKEY|CON_ID|OWNER|TABLE_NAME|TABLE_NUM_ROWS|TAB|PARTITIONED|COLUMN_NAME|DATA_TYPE|TABLE_PARTITION_NAME|TABLE_PARTITION_SEG_CREATED|PARTITION_NUM_ROWS|LOB_PARTITION_NAME|LOB_PARTITION_SEG_CREATED|SUBPARTITION_COUNT|TABLE_SUBPARTITION_NAME|TABLE_SUBPARTITION_CREATED|SUBPARTITION_NUM_ROWS|LOB_SUBPARTITION_NAME|LOB_SUBPARTITION_SEG_CREATED|LOB_SEG_NAME|SEG_NAME|SEG_PARTITION_NAME|LOB_COMPRESSION|LOB_PARTITION_COMPRESSION|LOB_SUBPARTITION_COMPRESSION|LOB_DEDUPLICATION|LOB_PARTITION_DEDUPLICATION|LOB_SUBPARTITION_DEDUPLICATION|SEG_BYTES|TABLE_AVG_LOB_BYTES|PARTITION_AVG_LOB_BYTES|SUBPARTITION_AVG_LOB_BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
@sql/extracts/lobsizing.sql
spool off


spool &outputdir./opdb__eoj__&s_tag.
prompt END_OF_DMA_COLLECTION
@sql/extracts/eoj.sql
spool off



BEGIN
DBMS_SQL_MONITOR.BEGIN_OPERATION (
   dbop_name       => 'DMA COLLECTOR',
   dbop_eid        => :EID);
END;
/

set termout on
prompt Step completed.
prompt
prompt Database Migration Assessment data successfully extracted.
prompt
exit
