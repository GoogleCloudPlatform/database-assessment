-- name: pre-process-02-create_schema#
-- Create all tables for loaded data
CREATE TABLE IF NOT EXISTS AWRHISTCMDTYPES (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    HH24 SMALLINT,
    COMMAND_TYPE SMALLINT,
    CNT BIGINT,
    AVG_BUFFER_GETS BIGINT,
    AVG_ELASPED_TIME BIGINT,
    AVG_ROWS_PROCESSED BIGINT,
    AVG_EXECUTIONS BIGINT,
    AVG_CPU_TIME BIGINT,
    AVG_IOWAIT BIGINT,
    AVG_CLWAIT BIGINT,
    AVG_APWAIT BIGINT,
    AVG_CCWAIT BIGINT,
    AVG_PLSEXEC_TIME BIGINT
);


CREATE TABLE IF NOT EXISTS AWRHISTOSSTAT (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HH24 SMALLINT,
    STAT_NAME VARCHAR(64),
    HH24_TOTAL_SECS BIGINT,
    CUMULATIVE_VALUE BIGINT,
    AVG_VALUE BIGINT,
    MODE_VALUE BIGINT,
    MEDIAN_VALUE BIGINT,
    PERC50 BIGINT,
    PERC75 BIGINT,
    PERC90 BIGINT,
    PERC95 BIGINT,
    PERC100 BIGINT,
    MIN_VALUE BIGINT,
    MAX_VALUE BIGINT,
    SUM_VALUE BIGINT,
    COUNT BIGINT
);


CREATE TABLE IF NOT EXISTS AWRHISTSYSMETRICHIST (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    METRIC_NAME VARCHAR(64),
    METRIC_UNIT VARCHAR(64),
    AVG_VALUE BIGINT,
    MODE_VALUE BIGINT,
    MEDIAN_VALUE BIGINT,
    MIN_VALUE BIGINT,
    MAX_VALUE BIGINT,
    SUM_VALUE BIGINT,
    PERC50 BIGINT,
    PERC75 BIGINT,
    PERC90 BIGINT,
    PERC95 BIGINT,
    PERC100 BIGINT
);


CREATE TABLE IF NOT EXISTS AWRHISTSYSMETRICSUMM (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    METRIC_NAME VARCHAR(64),
    METRIC_UNIT VARCHAR(64),
    AVG_VALUE BIGINT,
    MODE_VALUE BIGINT,
    MEDIAN_VALUE BIGINT,
    MIN_VALUE BIGINT,
    MAX_VALUE BIGINT,
    SUM_VALUE BIGINT,
    PERC50 BIGINT,
    PERC75 BIGINT,
    PERC90 BIGINT,
    PERC95 BIGINT,
    PERC100 BIGINT
);


CREATE TABLE IF NOT EXISTS AWRSNAPDETAILS (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    MIN_SNAP_ID BIGINT,
    MAX_SNAP_ID BIGINT,
    MIN_BEGIN_INTERVAL_TIME VARCHAR(40),
    MAX_BEGIN_INTERVAL_TIME VARCHAR(40),
    CNT BIGINT,
    SUM_SNAPS_DIFF_SECS BIGINT,
    AVG_SNAPS_DIFF_SECS BIGINT,
    MEDIAN_SNAPS_DIFF_SECS BIGINT,
    MODE_SNAPS_DIFF_SECS BIGINT,
    MIN_SNAPS_DIFF_SECS BIGINT,
    MAX_SNAPS_DIFF_SECS BIGINT
);


CREATE TABLE IF NOT EXISTS COMPRESSBYTYPE (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    BASIC BIGINT,
    OLTP BIGINT,
    QUERY_LOW BIGINT,
    QUERY_HIGH BIGINT,
    ARCHIVE_LOW BIGINT,
    ARCHIVE_HIGH BIGINT,
    TOTAL_GB BIGINT
);


CREATE TABLE IF NOT EXISTS CPUCORESUSAGE (
    PKEY VARCHAR(256),
    DT VARCHAR(14),
    CPU_COUNT BIGINT,
    CPU_CORE_COUNT BIGINT,
    CPU_SOCKET_COUNT BIGINT
);


CREATE TABLE IF NOT EXISTS DATAGUARD (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    INST_ID BIGINT,
    LOG_ARCHIVE_CONFIG VARCHAR(4000),
    DEST_ID BIGINT,
    DEST_NAME VARCHAR(256),
    DESTINATION VARCHAR(256),
    STATUS VARCHAR(9),
    TARGET VARCHAR(16),
    SCHEDULE VARCHAR(8),
    REGISTER VARCHAR(3),
    ALTERNATE VARCHAR(256),
    TRANSMIT_MODE VARCHAR(12),
    AFFIRM VARCHAR(3),
    VALID_ROLE VARCHAR(12),
    VERIFY VARCHAR(3)
);


CREATE TABLE IF NOT EXISTS DATATYPES (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    DATA_TYPE VARCHAR(128),
    CNT BIGINT
);


CREATE TABLE IF NOT EXISTS DBAHISTSYSSTAT (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    STAT_NAME VARCHAR(64),
    CNT BIGINT,
    AVG_VALUE BIGINT,
    MODE_VALUE BIGINT,
    MEDIAN_VALUE BIGINT,
    MIN_VALUE BIGINT,
    MAX_VALUE BIGINT,
    SUM_VALUE BIGINT,
    PERC50 BIGINT,
    PERC75 BIGINT,
    PERC90 BIGINT,
    PERC95 BIGINT,
    PERC100 BIGINT
);


CREATE TABLE IF NOT EXISTS DBAHISTSYSTIMEMODEL (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    STAT_NAME VARCHAR(64),
    CNT BIGINT,
    AVG_VALUE BIGINT,
    MODE_VALUE BIGINT,
    MEDIAN_VALUE BIGINT,
    MIN_VALUE BIGINT,
    MAX_VALUE BIGINT,
    SUM_VALUE BIGINT,
    PERC50 BIGINT,
    PERC75 BIGINT,
    PERC90 BIGINT,
    PERC95 BIGINT,
    PERC100 BIGINT
);


CREATE TABLE IF NOT EXISTS DBFEATURES (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    NAME VARCHAR(128),
    CURRENT_USAGE VARCHAR(5),
    DETECTED_USAGES BIGINT,
    TOTAL_SAMPLES BIGINT,
    FIRST_USAGE VARCHAR(14),
    LAST_USAGE VARCHAR(14),
    AUX_COUNT NUMERIC
);


CREATE TABLE IF NOT EXISTS DBHWMARKSTATISTICS (
    PKEY VARCHAR(256),
    DESCRIPTION VARCHAR(128),
    HIGHWATER NUMERIC,
    LAST_VALUE NUMERIC
);


CREATE TABLE IF NOT EXISTS DBINSTANCES (
    PKEY VARCHAR(256),
    INST_ID BIGINT,
    INSTANCE_NAME VARCHAR(16),
    HOST_NAME VARCHAR(64),
    VERSION VARCHAR(17),
    STATUS VARCHAR(12),
    DATABASE_STATUS VARCHAR(17),
    INSTANCE_ROLE VARCHAR(18)
);


CREATE TABLE IF NOT EXISTS DBLINKS (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    COUNT BIGINT
);


CREATE TABLE IF NOT EXISTS DBOBJECTS (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    OBJECT_TYPE VARCHAR(23),
    EDITIONABLE VARCHAR(3),
    COUNT BIGINT,
    IN_CON_ID VARCHAR(40),
    IN_OWNER BIGINT,
    IN_OBJECT_TYPE BIGINT,
    IN_EDITIONABLE VARCHAR(40)
);


CREATE TABLE IF NOT EXISTS DBPARAMETERS (
    PKEY VARCHAR(256),
    INST_ID BIGINT,
    CON_ID SMALLINT,
    NAME VARCHAR(80),
    VALUE VARCHAR(960),
    DEFAULT_VALUE VARCHAR(480),
    ISDEFAULT VARCHAR(9)
);


CREATE TABLE IF NOT EXISTS DBSUMMARY (
    PKEY VARCHAR(256),
    DBID BIGINT,
    DB_NAME VARCHAR(9),
    CDB VARCHAR(3),
    DB_VERSION VARCHAR(17),
    DB_FULLVERSION VARCHAR(80),
    LOG_MODE VARCHAR(12),
    FORCE_LOGGING VARCHAR(39),
    REDO_GB_PER_DAY BIGINT,
    RAC_DBINSTACES BIGINT,
    CHARACTERSET VARCHAR(770),
    PLATFORM_NAME VARCHAR(101),
    STARTUP_TIME VARCHAR(17),
    USER_SCHEMAS BIGINT,
    BUFFER_CACHE_MB BIGINT,
    SHARED_POOL_MB BIGINT,
    TOTAL_PGA_ALLOCATED_MB BIGINT,
    DB_SIZE_ALLOCATED_GB BIGINT,
    DB_SIZE_IN_USE_GB BIGINT,
    DB_LONG_SIZE_GB BIGINT,
    DG_DATABASE_ROLE VARCHAR(16),
    DG_PROTECTION_MODE VARCHAR(20),
    DG_PROTECTION_LEVEL VARCHAR(20)
);


CREATE TABLE IF NOT EXISTS EXTTAB (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    TABLE_NAME VARCHAR(128),
    TYPE_OWNER VARCHAR(3),
    TYPE_NAME VARCHAR(128),
    DEFAULT_DIRECTORY_OWNER VARCHAR(3),
    DEFAULT_DIRECTORY_NAME VARCHAR(128)
);


CREATE TABLE IF NOT EXISTS IDXPERTABLE (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    TAB_COUNT BIGINT,
    IDX_CNT BIGINT,
    IDX_PERC BIGINT
);


CREATE TABLE IF NOT EXISTS INDEXESTYPES (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    INDEX_TYPE VARCHAR(27),
    CNT BIGINT
);


CREATE TABLE IF NOT EXISTS IOEVENTS (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    WAIT_CLASS VARCHAR(64),
    EVENT_NAME VARCHAR(64),
    TOT_WAITS_DELTA_VALUE_P95 BIGINT,
    TOT_TOUT_DELTA_VALUE_P95 BIGINT,
    TIME_WA_US_DELTA_VALUE_P95 BIGINT
);


CREATE TABLE IF NOT EXISTS IOFUNCTION (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    FUNCTION_NAME VARCHAR(128),
    SM_READ_MB_DELTA_VALUE_P95 BIGINT,
    SM_WRITE_MB_DELTA_VALUE_P95 BIGINT,
    SM_READ_RQ_DELTA_VALUE_P95 BIGINT,
    SM_WRITE_RQ_DELTA_VALUE_P95 BIGINT,
    LG_READ_MB_DELTA_VALUE_P95 BIGINT,
    LG_WRITE_MB_DELTA_VALUE_P95 BIGINT,
    LG_READ_RQ_DELTA_VALUE_P95 BIGINT,
    LG_WRITE_RQ_DELTA_VALUE_P95 BIGINT,
    NO_IOWAIT_DELTA_VALUE_P95 BIGINT,
    TOT_WATIME_DELTA_VALUE_P95 BIGINT,
    TOTAL_READS_MB_P95 BIGINT,
    TOTAL_READS_REQ_P95 BIGINT,
    TOTAL_WRITES_MB_P95 BIGINT,
    TOTAL_WRITE_REQ_P95 BIGINT
);


CREATE TABLE IF NOT EXISTS PDBSINFO (
    PKEY VARCHAR(256),
    DBID BIGINT,
    PDB_ID BIGINT,
    PDB_NAME VARCHAR(128),
    STATUS VARCHAR(10),
    LOGGING VARCHAR(9)
);


CREATE TABLE IF NOT EXISTS PDBSOPENMODE (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    NAME VARCHAR(128),
    OPEN_MODE VARCHAR(10),
    TOTAL_GB NUMERIC
);


CREATE TABLE IF NOT EXISTS SOURCECODE (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    TYPE VARCHAR(12),
    SUM_NR_LINES BIGINT,
    QT_OBJS BIGINT,
    SUM_NR_LINES_W_UTL BIGINT,
    SUM_NR_LINES_W_DBMS BIGINT,
    COUNT_EXEC_IM BIGINT,
    COUNT_DBMS_SQL BIGINT,
    SUM_NR_LINES_W_DBMS_UTL BIGINT,
    SUM_COUNT_TOTAL BIGINT
);


CREATE TABLE IF NOT EXISTS SOURCECONN (
    PKEY VARCHAR(256),
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    HOUR SMALLINT,
    PROGRAM VARCHAR(84),
    MODULE VARCHAR(64),
    MACHINE VARCHAR(64),
    COMMAND_NAME VARCHAR(64),
    CNT BIGINT
);


CREATE TABLE IF NOT EXISTS SQLSTATS (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    DBID BIGINT,
    INSTANCE_NUMBER SMALLINT,
    FORCE_MATCHING_SIGNATURE VARCHAR(40),
    SQL_ID VARCHAR(13),
    TOTAL_EXECUTIONS BIGINT,
    TOTAL_PX_SERVERS_EXECS BIGINT,
    ELAPSED_TIME_TOTAL BIGINT,
    DISK_READS_TOTAL BIGINT,
    PHYSICAL_READ_BYTES_TOTAL BIGINT,
    PHYSICAL_WRITE_BYTES_TOTAL BIGINT,
    IO_OFFLOAD_ELIG_BYTES_TOTAL BIGINT,
    IO_INTERCONNECT_BYTES_TOTAL BIGINT,
    OPTIMIZED_PHYSICAL_READS_TOTAL BIGINT,
    CELL_UNCOMPRESSED_BYTES_TOTAL BIGINT,
    IO_OFFLOAD_RETURN_BYTES_TOTAL BIGINT,
    DIRECT_WRITES_TOTAL BIGINT,
    PERC_EXEC_FINISHED BIGINT,
    AVG_ROWS BIGINT,
    AVG_DISK_READS BIGINT,
    AVG_BUFFER_GETS BIGINT,
    AVG_CPU_TIME_US BIGINT,
    AVG_ELAPSED_US BIGINT,
    AVG_IOWAIT_US BIGINT,
    AVG_CLWAIT_US BIGINT,
    AVG_APWAIT_US BIGINT,
    AVG_CCWAIT_US BIGINT,
    AVG_PLSEXEC_US BIGINT,
    AVG_JAVEXEC_US BIGINT
);


CREATE TABLE IF NOT EXISTS TABLESNOPK (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    PK BIGINT,
    UK BIGINT,
    CK BIGINT,
    RI BIGINT,
    VWCK BIGINT,
    VWRO BIGINT,
    HASHEXPR BIGINT,
    SUPLOG BIGINT,
    NUM_TABLES BIGINT,
    TOTAL_CONS BIGINT
);


CREATE TABLE IF NOT EXISTS USEDSPACEDETAILS (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    SEGMENT_TYPE VARCHAR(18),
    GB BIGINT
);


CREATE TABLE IF NOT EXISTS USRSEGATT (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    SEGMENT_NAME VARCHAR(128),
    SEGMENT_TYPE VARCHAR(18),
    TABLESPACE_NAME VARCHAR(30)
);


CREATE TABLE IF NOT EXISTS optimusconfig_bms_machinesizes (
    cores VARCHAR(128),
    ram_gb VARCHAR(128),
    machine_size VARCHAR(128),
    machine_size_short VARCHAR(128),
    processor VARCHAR(128),
    est_price VARCHAR(128)
);


CREATE TABLE IF NOT EXISTS optimusconfig_network_to_gcp (
    network_to_gcp VARCHAR(128),
    gbytes_per_sec VARCHAR(128),
    mbytes_per_sec VARCHAR(128)
);


CREATE TABLE IF NOT EXISTS vsysstat_columnar (
    dbversion VARCHAR(10),
    metric_unit VARCHAR(100),
    info_source VARCHAR(100),
    pkey VARCHAR(100),
    dbid NUMERIC,
    instance_number NUMERIC,
    hour NUMERIC,
    cpu_used_by_this_session_perc50 NUMERIC,
    cpu_used_by_this_session_perc75 NUMERIC,
    cpu_used_by_this_session_perc95 NUMERIC,
    cpu_used_by_this_session_perc100 NUMERIC,
    dbtime_perc50 NUMERIC,
    dbtime_perc75 NUMERIC,
    dbtime_perc95 NUMERIC,
    dbtime_perc100 NUMERIC,
    cellflashcachereadhit_perc50 NUMERIC,
    cellflashcachereadhit_perc75 NUMERIC,
    cellflashcachereadhit_perc95 NUMERIC,
    cellflashcachereadhit_perc100 NUMERIC,
    cell_inter_bytes_returned_by_XT_smartscan_perc50 NUMERIC,
    cell_inter_bytes_returned_by_XT_smartscan_perc75 NUMERIC,
    cell_inter_bytes_returned_by_XT_smartscan_perc95 NUMERIC,
    cell_inter_bytes_returned_by_XT_smartscan_perc100 NUMERIC,
    cell_io_bytes_eligible_for_predicate_offload_perc50 NUMERIC,
    cell_io_bytes_eligible_for_predicate_offload_perc75 NUMERIC,
    cell_io_bytes_eligible_for_predicate_offload_perc95 NUMERIC,
    cell_io_bytes_eligible_for_predicate_offload_perc100 NUMERIC,
    cell_io_bytes_eligible_for_smartios_perc50 NUMERIC,
    cell_io_bytes_eligible_for_smartios_perc75 NUMERIC,
    cell_io_bytes_eligible_for_smartios_perc95 NUMERIC,
    cell_io_bytes_eligible_for_smartios_perc100 NUMERIC,
    cell_io_bytes_saved_by_storage_index_perc50 NUMERIC,
    cell_io_bytes_saved_by_storage_index_perc75 NUMERIC,
    cell_io_bytes_saved_by_storage_index_perc95 NUMERIC,
    cell_io_bytes_saved_by_storage_index_perc100 NUMERIC,
    cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50 NUMERIC,
    cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75 NUMERIC,
    cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95 NUMERIC,
    cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100 NUMERIC,
    cell_io_interconnect_bytes_perc50 NUMERIC,
    cell_io_interconnect_bytes_perc75 NUMERIC,
    cell_io_interconnect_bytes_perc95 NUMERIC,
    cell_io_interconnect_bytes_perc100 NUMERIC,
    cell_io_interconnect_bytes_returned_by_smartcan_perc50 NUMERIC,
    cell_io_interconnect_bytes_returned_by_smartcan_perc75 NUMERIC,
    cell_io_interconnect_bytes_returned_by_smartcan_perc95 NUMERIC,
    cell_io_interconnect_bytes_returned_by_smartcan_perc100 NUMERIC,
    cell_physical_write_io_bytes_eligible_for_offload_perc50 NUMERIC,
    cell_physical_write_io_bytes_eligible_for_offload_perc75 NUMERIC,
    cell_physical_write_io_bytes_eligible_for_offload_perc95 NUMERIC,
    cell_physical_write_io_bytes_eligible_for_offload_perc100 NUMERIC,
    cell_pmem_cache_read_hits_perc50 NUMERIC,
    cell_pmem_cache_read_hits_perc75 NUMERIC,
    cell_pmem_cache_read_hits_perc95 NUMERIC,
    cell_pmem_cache_read_hits_perc100 NUMERIC,
    dbblockgets_perc50 NUMERIC,
    dbblockgets_perc75 NUMERIC,
    dbblockgets_perc95 NUMERIC,
    execute_count_perc50 NUMERIC,
    execute_count_perc75 NUMERIC,
    execute_count_perc95 NUMERIC,
    execute_count_perc100 NUMERIC,
    physical_read_io_requests_perc50 NUMERIC,
    physical_read_io_requests_perc75 NUMERIC,
    physical_read_io_requests_perc95 NUMERIC,
    physical_read_io_requests_perc100 NUMERIC,
    physical_read_bytes_perc50 NUMERIC,
    physical_read_bytes_perc75 NUMERIC,
    physical_read_bytes_perc95 NUMERIC,
    physical_read_bytes_perc100 NUMERIC,
    physical_read_flash_cache_hits_perc50 NUMERIC,
    physical_read_flash_cache_hits_perc75 NUMERIC,
    physical_read_flash_cache_hits_perc95 NUMERIC,
    physical_read_flash_cache_hits_perc100 NUMERIC,
    physical_read_total_io_requests_perc50 NUMERIC,
    physical_read_total_io_requests_perc75 NUMERIC,
    physical_read_total_io_requests_perc95 NUMERIC,
    physical_read_total_io_requests_perc100 NUMERIC,
    physical_read_total_bytes_perc50 NUMERIC,
    physical_read_total_bytes_perc75 NUMERIC,
    physical_read_total_bytes_perc95 NUMERIC,
    physical_read_total_bytes_perc100 NUMERIC,
    physical_reads_perc50 NUMERIC,
    physical_reads_perc75 NUMERIC,
    physical_reads_perc95 NUMERIC,
    physical_reads_perc100 NUMERIC,
    physical_reads_direct_perc50 NUMERIC,
    physical_reads_direct_perc75 NUMERIC,
    physical_reads_direct_perc95 NUMERIC,
    physical_reads_direct_perc100 NUMERIC,
    physical_reads_direct_lob_perc50 NUMERIC,
    physical_reads_direct_lob_perc75 NUMERIC,
    physical_reads_direct_lob_perc95 NUMERIC,
    physical_reads_direct_lob_perc100 NUMERIC,
    physical_write_io_req_perc50 NUMERIC,
    physical_write_io_req_perc75 NUMERIC,
    physical_write_io_req_perc95 NUMERIC,
    physical_write_io_req_perc100 NUMERIC,
    physical_write_bytes_perc50 NUMERIC,
    physical_write_bytes_perc75 NUMERIC,
    physical_write_bytes_perc95 NUMERIC,
    physical_write_bytes_perc100 NUMERIC,
    physical_write_total_io_req_perc50 NUMERIC,
    physical_write_total_io_req_perc75 NUMERIC,
    physical_write_total_io_req_perc95 NUMERIC,
    physical_write_total_io_req_perc100 NUMERIC,
    physical_write_total_bytes_perc50 NUMERIC,
    physical_write_total_bytes_perc75 NUMERIC,
    physical_write_total_bytes_perc95 NUMERIC,
    physical_write_total_bytes_perc100 NUMERIC,
    physical_writes_perc50 NUMERIC,
    physical_writes_perc75 NUMERIC,
    physical_writes_perc95 NUMERIC,
    physical_writes_perc100 NUMERIC,
    physical_writes_direct_lob_perc50 NUMERIC,
    physical_writes_direct_lob_perc75 NUMERIC,
    physical_writes_direct_lob_perc95 NUMERIC,
    physical_writes_direct_lob_perc100 NUMERIC,
    recursive_cpu_usage_perc50 NUMERIC,
    recursive_cpu_usage_perc75 NUMERIC,
    recursive_cpu_usage_perc95 NUMERIC,
    recursive_cpu_usage_perc100 NUMERIC,
    user_io_wait_time_perc50 NUMERIC,
    user_io_wait_time_perc75 NUMERIC,
    user_io_wait_time_perc95 NUMERIC,
    user_io_wait_time_perc100 NUMERIC,
    user_calls_perc50 NUMERIC,
    user_calls_perc75 NUMERIC,
    user_calls_perc95 NUMERIC,
    user_calls_perc100 NUMERIC,
    user_commits_perc50 NUMERIC,
    user_commits_perc75 NUMERIC,
    user_commits_perc95 NUMERIC,
    user_commits_perc100 NUMERIC,
    user_rollbacks_perc50 NUMERIC,
    user_rollbacks_perc75 NUMERIC,
    user_rollbacks_perc95 NUMERIC,
    user_rollbacks_perc100 NUMERIC
);