-- name: drop_all_objects#
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

-- name: create_tables#
-- Create all tables for loaded data
CREATE TABLE AWRHISTCMDTYPES (
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

CREATE TABLE AWRHISTOSSTAT (
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

CREATE TABLE AWRHISTSYSMETRICHIST (
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

CREATE TABLE AWRHISTSYSMETRICSUMM (
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

CREATE TABLE AWRSNAPDETAILS (
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

CREATE TABLE COMPRESSBYTYPE (
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

CREATE TABLE CPUCORESUSAGE (
    PKEY VARCHAR(256),
    DT VARCHAR(14),
    CPU_COUNT BIGINT,
    CPU_CORE_COUNT BIGINT,
    CPU_SOCKET_COUNT BIGINT
);

CREATE TABLE DATAGUARD (
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

CREATE TABLE DATATYPES (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    DATA_TYPE VARCHAR(128),
    CNT BIGINT
);

CREATE TABLE DBAHISTSYSSTAT (
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

CREATE TABLE DBAHISTSYSTIMEMODEL (
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

CREATE TABLE DBFEATURES (
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

CREATE TABLE DBHWMARKSTATISTICS (
    PKEY VARCHAR(256),
    DESCRIPTION VARCHAR(128),
    HIGHWATER NUMERIC,
    LAST_VALUE NUMERIC
);

CREATE TABLE DBINSTANCES (
    PKEY VARCHAR(256),
    INST_ID BIGINT,
    INSTANCE_NAME VARCHAR(16),
    HOST_NAME VARCHAR(64),
    VERSION VARCHAR(17),
    STATUS VARCHAR(12),
    DATABASE_STATUS VARCHAR(17),
    INSTANCE_ROLE VARCHAR(18)
);

CREATE TABLE DBLINKS (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    COUNT BIGINT
);

CREATE TABLE DBOBJECTS (
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

CREATE TABLE DBPARAMETERS (
    PKEY VARCHAR(256),
    INST_ID BIGINT,
    CON_ID SMALLINT,
    NAME VARCHAR(80),
    VALUE VARCHAR(960),
    DEFAULT_VALUE VARCHAR(480),
    ISDEFAULT VARCHAR(9)
);

CREATE TABLE DBSUMMARY (
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

CREATE TABLE EXTTAB (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    TABLE_NAME VARCHAR(128),
    TYPE_OWNER VARCHAR(3),
    TYPE_NAME VARCHAR(128),
    DEFAULT_DIRECTORY_OWNER VARCHAR(3),
    DEFAULT_DIRECTORY_NAME VARCHAR(128)
);

CREATE TABLE IDXPERTABLE (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    TAB_COUNT BIGINT,
    IDX_CNT BIGINT,
    IDX_PERC BIGINT
);

CREATE TABLE INDEXESTYPES (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    INDEX_TYPE VARCHAR(27),
    CNT BIGINT
);

CREATE TABLE IOEVENTS (
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

CREATE TABLE IOFUNCTION (
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

CREATE TABLE PDBSINFO (
    PKEY VARCHAR(256),
    DBID BIGINT,
    PDB_ID BIGINT,
    PDB_NAME VARCHAR(128),
    STATUS VARCHAR(10),
    LOGGING VARCHAR(9)
);

CREATE TABLE PDBSOPENMODE (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    NAME VARCHAR(128),
    OPEN_MODE VARCHAR(10),
    TOTAL_GB NUMERIC
);

CREATE TABLE SOURCECODE (
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

CREATE TABLE SOURCECONN (
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

CREATE TABLE SQLSTATS (
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

CREATE TABLE TABLESNOPK (
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

CREATE TABLE USEDSPACEDETAILS (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    SEGMENT_TYPE VARCHAR(18),
    GB BIGINT
);

CREATE TABLE USRSEGATT (
    PKEY VARCHAR(256),
    CON_ID SMALLINT,
    OWNER VARCHAR(128),
    SEGMENT_NAME VARCHAR(128),
    SEGMENT_TYPE VARCHAR(18),
    TABLESPACE_NAME VARCHAR(30)
);

CREATE TABLE optimusconfig_bms_machinesizes (
    cores VARCHAR(128),
    ram_gb VARCHAR(128),
    machine_size VARCHAR(128),
    machine_size_short VARCHAR(128),
    processor VARCHAR(128),
    est_price VARCHAR(128)
);

CREATE TABLE optimusconfig_network_to_gcp (
    network_to_gcp VARCHAR(128),
    gbytes_per_sec VARCHAR(128),
    mbytes_per_sec VARCHAR(128)
);

CREATE TABLE vsysstat_columnar (
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

-- name: drop_all_objects#
-- Drop all objects in the in-memory duckdb engine
INSERT INTO
    vsysstat_columnar WITH v_dbahistsysstat as (
        select
            'HIST_SYSSTAT' info_source,
            a.*,
            round(a.avg_value / b.avg_snaps_diff_secs, 1) avg_value_per_sec,
            round(a.mode_value / b.avg_snaps_diff_secs, 1) mode_value_per_sec,
            round(a.median_value / b.avg_snaps_diff_secs, 1) median_value_per_sec,
            round(a.perc50 / b.avg_snaps_diff_secs, 1) perc50_value_per_sec,
            round(a.perc75 / b.avg_snaps_diff_secs, 1) perc75_value_per_sec,
            round(a.perc90 / b.avg_snaps_diff_secs, 1) perc90_value_per_sec,
            round(a.perc95 / b.avg_snaps_diff_secs, 1) perc95_value_per_sec,
            round(a.perc100 / b.avg_snaps_diff_secs, 1) perc100_value_per_sec
        from
            dbahistsysstat a
            inner join awrsnapdetails b on a.pkey = b.pkey
            and a.dbid = b.dbid
            and a.instance_number = b.instance_number
            and a.hour = b.hour
    ),
    vsysstat_part1 as (
        select
            a.info_source,
            a.pkey,
            a.dbid,
            a.instance_number,
            a.hour,
            case
                when stat_name = 'CPU used by this session' then perc50_value_per_sec
            end cpu_used_by_this_session_perc50,
            case
                when stat_name = 'CPU used by this session' then perc75_value_per_sec
            end cpu_used_by_this_session_perc75,
            case
                when stat_name = 'CPU used by this session' then perc95_value_per_sec
            end cpu_used_by_this_session_perc95,
            case
                when stat_name = 'CPU used by this session' then perc100_value_per_sec
            end cpu_used_by_this_session_perc100,
            case
                when stat_name = 'DB time' then perc50_value_per_sec
            end dbtime_perc50,
            case
                when stat_name = 'DB time' then perc75_value_per_sec
            end dbtime_perc75,
            case
                when stat_name = 'DB time' then perc95_value_per_sec
            end dbtime_perc95,
            case
                when stat_name = 'DB time' then perc100_value_per_sec
            end dbtime_perc100,
            case
                when stat_name = 'cell flash cache read hits' then perc50_value_per_sec
            end cellflashcachereadhit_perc50,
            case
                when stat_name = 'cell flash cache read hits' then perc75_value_per_sec
            end cellflashcachereadhit_perc75,
            case
                when stat_name = 'cell flash cache read hits' then perc95_value_per_sec
            end cellflashcachereadhit_perc95,
            case
                when stat_name = 'cell flash cache read hits' then perc100_value_per_sec
            end cellflashcachereadhit_perc100,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc50_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc50,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc75_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc75,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc95_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc95,
            case
                when stat_name = 'cell interconnect bytes returned by XT smart scan' then perc100_value_per_sec
            end cell_inter_bytes_returned_by_XT_smartscan_perc100,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc50_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc50,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc75_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc75,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc95_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc95,
            case
                when stat_name = 'cell physical IO bytes eligible for predicate offload' then perc100_value_per_sec
            end cell_io_bytes_eligible_for_predicate_offload_perc100,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc50_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc50,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc75_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc75,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc95_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc95,
            case
                when stat_name = 'cell physical IO bytes eligible for smart IOs' then perc100_value_per_sec
            end cell_io_bytes_eligible_for_smartios_perc100,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc50_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc50,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc75_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc75,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc95_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc95,
            case
                when stat_name = 'cell physical IO bytes saved by storage index' then perc100_value_per_sec
            end cell_io_bytes_saved_by_storage_index_perc100,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc50_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc75_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc95_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95,
            case
                when stat_name = 'cell physical IO bytes sent directly to DB node to balance CPU' then perc100_value_per_sec
            end cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc50_value_per_sec
            end cell_io_interconnect_bytes_perc50,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc75_value_per_sec
            end cell_io_interconnect_bytes_perc75,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc95_value_per_sec
            end cell_io_interconnect_bytes_perc95,
            case
                when stat_name = 'cell physical IO interconnect bytes' then perc100_value_per_sec
            end cell_io_interconnect_bytes_perc100,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc50_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc50,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc75_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc75,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc95_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc95,
            case
                when stat_name = 'cell physical IO interconnect bytes returned by smart scan' then perc100_value_per_sec
            end cell_io_interconnect_bytes_returned_by_smartcan_perc100,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc50_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc50,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc75_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc75,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc95_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc95,
            case
                when stat_name = 'cell physical write IO bytes eligible for offload' then perc100_value_per_sec
            end cell_physical_write_io_bytes_eligible_for_offload_perc100,
            case
                when stat_name = 'cell pmem cache read hits' then perc50_value_per_sec
            end cell_pmem_cache_read_hits_perc50,
            case
                when stat_name = 'cell pmem cache read hits' then perc75_value_per_sec
            end cell_pmem_cache_read_hits_perc75,
            case
                when stat_name = 'cell pmem cache read hits' then perc95_value_per_sec
            end cell_pmem_cache_read_hits_perc95,
            case
                when stat_name = 'cell pmem cache read hits' then perc100_value_per_sec
            end cell_pmem_cache_read_hits_perc100,
            case
                when stat_name = 'db block gets' then perc50_value_per_sec
            end dbblockgets_perc50,
            case
                when stat_name = 'db block gets' then perc75_value_per_sec
            end dbblockgets_perc75,
            case
                when stat_name = 'db block gets' then perc95_value_per_sec
            end dbblockgets_perc95,
            case
                when stat_name = 'db block gets' then perc100_value_per_sec
            end dbblockgets_perc100,
            case
                when stat_name = 'execute count' then perc50_value_per_sec
            end execute_count_perc50,
            case
                when stat_name = 'execute count' then perc75_value_per_sec
            end execute_count_perc75,
            case
                when stat_name = 'execute count' then perc95_value_per_sec
            end execute_count_perc95,
            case
                when stat_name = 'execute count' then perc100_value_per_sec
            end execute_count_perc100,
            case
                when stat_name = 'physical read IO requests' then perc50_value_per_sec
            end physical_read_io_requests_perc50,
            case
                when stat_name = 'physical read IO requests' then perc75_value_per_sec
            end physical_read_io_requests_perc75,
            case
                when stat_name = 'physical read IO requests' then perc95_value_per_sec
            end physical_read_io_requests_perc95,
            case
                when stat_name = 'physical read IO requests' then perc100_value_per_sec
            end physical_read_io_requests_perc100,
            case
                when stat_name = 'physical read bytes' then perc50_value_per_sec
            end physical_read_bytes_perc50,
            case
                when stat_name = 'physical read bytes' then perc75_value_per_sec
            end physical_read_bytes_perc75,
            case
                when stat_name = 'physical read bytes' then perc95_value_per_sec
            end physical_read_bytes_perc95,
            case
                when stat_name = 'physical read bytes' then perc100_value_per_sec
            end physical_read_bytes_perc100,
            case
                when stat_name = 'physical read flash cache hits' then perc50_value_per_sec
            end physical_read_flash_cache_hits_perc50,
            case
                when stat_name = 'physical read flash cache hits' then perc75_value_per_sec
            end physical_read_flash_cache_hits_perc75,
            case
                when stat_name = 'physical read flash cache hits' then perc95_value_per_sec
            end physical_read_flash_cache_hits_perc95,
            case
                when stat_name = 'physical read flash cache hits' then perc100_value_per_sec
            end physical_read_flash_cache_hits_perc100,
            case
                when stat_name = 'physical read total IO requests' then perc50_value_per_sec
            end physical_read_total_io_requests_perc50,
            case
                when stat_name = 'physical read total IO requests' then perc75_value_per_sec
            end physical_read_total_io_requests_perc75,
            case
                when stat_name = 'physical read total IO requests' then perc95_value_per_sec
            end physical_read_total_io_requests_perc95,
            case
                when stat_name = 'physical read total IO requests' then perc100_value_per_sec
            end physical_read_total_io_requests_perc100,
            case
                when stat_name = 'physical read total bytes' then perc50_value_per_sec
            end physical_read_total_bytes_perc50,
            case
                when stat_name = 'physical read total bytes' then perc75_value_per_sec
            end physical_read_total_bytes_perc75,
            case
                when stat_name = 'physical read total bytes' then perc95_value_per_sec
            end physical_read_total_bytes_perc95,
            case
                when stat_name = 'physical read total bytes' then perc100_value_per_sec
            end physical_read_total_bytes_perc100,
            case
                when stat_name = 'physical reads' then perc50_value_per_sec
            end physical_reads_perc50,
            case
                when stat_name = 'physical reads' then perc75_value_per_sec
            end physical_reads_perc75,
            case
                when stat_name = 'physical reads' then perc95_value_per_sec
            end physical_reads_perc95,
            case
                when stat_name = 'physical reads' then perc100_value_per_sec
            end physical_reads_perc100,
            case
                when stat_name = 'physical reads direct' then perc50_value_per_sec
            end physical_reads_direct_perc50,
            case
                when stat_name = 'physical reads direct' then perc75_value_per_sec
            end physical_reads_direct_perc75,
            case
                when stat_name = 'physical reads direct' then perc95_value_per_sec
            end physical_reads_direct_perc95,
            case
                when stat_name = 'physical reads direct' then perc100_value_per_sec
            end physical_reads_direct_perc100,
            case
                when stat_name = 'physical reads direct (lob)' then perc50_value_per_sec
            end physical_reads_direct_lob_perc50,
            case
                when stat_name = 'physical reads direct (lob)' then perc75_value_per_sec
            end physical_reads_direct_lob_perc75,
            case
                when stat_name = 'physical reads direct (lob)' then perc95_value_per_sec
            end physical_reads_direct_lob_perc95,
            case
                when stat_name = 'physical reads direct (lob)' then perc100_value_per_sec
            end physical_reads_direct_lob_perc100,
            case
                when stat_name = 'physical write IO requests' then perc50_value_per_sec
            end physical_write_io_req_perc50,
            case
                when stat_name = 'physical write IO requests' then perc75_value_per_sec
            end physical_write_io_req_perc75,
            case
                when stat_name = 'physical write IO requests' then perc95_value_per_sec
            end physical_write_io_req_perc95,
            case
                when stat_name = 'physical write IO requests' then perc100_value_per_sec
            end physical_write_io_req_perc100,
            case
                when stat_name = 'physical write bytes' then perc50_value_per_sec
            end physical_write_bytes_perc50,
            case
                when stat_name = 'physical write bytes' then perc75_value_per_sec
            end physical_write_bytes_perc75,
            case
                when stat_name = 'physical write bytes' then perc95_value_per_sec
            end physical_write_bytes_perc95,
            case
                when stat_name = 'physical write bytes' then perc100_value_per_sec
            end physical_write_bytes_perc100,
            case
                when stat_name = 'physical write total IO requests' then perc50_value_per_sec
            end physical_write_total_io_req_perc50,
            case
                when stat_name = 'physical write total IO requests' then perc75_value_per_sec
            end physical_write_total_io_req_perc75,
            case
                when stat_name = 'physical write total IO requests' then perc95_value_per_sec
            end physical_write_total_io_req_perc95,
            case
                when stat_name = 'physical write total IO requests' then perc100_value_per_sec
            end physical_write_total_io_req_perc100,
            case
                when stat_name = 'physical write total bytes' then perc50_value_per_sec
            end physical_write_total_bytes_perc50,
            case
                when stat_name = 'physical write total bytes' then perc75_value_per_sec
            end physical_write_total_bytes_perc75,
            case
                when stat_name = 'physical write total bytes' then perc95_value_per_sec
            end physical_write_total_bytes_perc95,
            case
                when stat_name = 'physical write total bytes' then perc100_value_per_sec
            end physical_write_total_bytes_perc100,
            case
                when stat_name = 'physical writes' then perc50_value_per_sec
            end physical_writes_perc50,
            case
                when stat_name = 'physical writes' then perc75_value_per_sec
            end physical_writes_perc75,
            case
                when stat_name = 'physical writes' then perc95_value_per_sec
            end physical_writes_perc95,
            case
                when stat_name = 'physical writes' then perc100_value_per_sec
            end physical_writes_perc100,
            case
                when stat_name = 'physical writes direct (lob)' then perc50_value_per_sec
            end physical_writes_direct_lob_perc50,
            case
                when stat_name = 'physical writes direct (lob)' then perc75_value_per_sec
            end physical_writes_direct_lob_perc75,
            case
                when stat_name = 'physical writes direct (lob)' then perc95_value_per_sec
            end physical_writes_direct_lob_perc95,
            case
                when stat_name = 'physical writes direct (lob)' then perc100_value_per_sec
            end physical_writes_direct_lob_perc100,
            case
                when stat_name = 'recursive cpu usage' then perc50_value_per_sec
            end recursive_cpu_usage_perc50,
            case
                when stat_name = 'recursive cpu usage' then perc75_value_per_sec
            end recursive_cpu_usage_perc75,
            case
                when stat_name = 'recursive cpu usage' then perc95_value_per_sec
            end recursive_cpu_usage_perc95,
            case
                when stat_name = 'recursive cpu usage' then perc100_value_per_sec
            end recursive_cpu_usage_perc100,
            case
                when stat_name = 'user I/O wait time' then perc50_value_per_sec
            end user_io_wait_time_perc50,
            case
                when stat_name = 'user I/O wait time' then perc75_value_per_sec
            end user_io_wait_time_perc75,
            case
                when stat_name = 'user I/O wait time' then perc95_value_per_sec
            end user_io_wait_time_perc95,
            case
                when stat_name = 'user I/O wait time' then perc100_value_per_sec
            end user_io_wait_time_perc100,
            case
                when stat_name = 'user calls' then perc50_value_per_sec
            end user_calls_perc50,
            case
                when stat_name = 'user calls' then perc75_value_per_sec
            end user_calls_perc75,
            case
                when stat_name = 'user calls' then perc95_value_per_sec
            end user_calls_perc95,
            case
                when stat_name = 'user calls' then perc100_value_per_sec
            end user_calls_perc100,
            case
                when stat_name = 'user commits' then perc50_value_per_sec
            end user_commits_perc50,
            case
                when stat_name = 'user commits' then perc75_value_per_sec
            end user_commits_perc75,
            case
                when stat_name = 'user commits' then perc95_value_per_sec
            end user_commits_perc95,
            case
                when stat_name = 'user commits' then perc100_value_per_sec
            end user_commits_perc100,
            case
                when stat_name = 'user rollbacks' then perc50_value_per_sec
            end user_rollbacks_perc50,
            case
                when stat_name = 'user rollbacks' then perc75_value_per_sec
            end user_rollbacks_perc75,
            case
                when stat_name = 'user rollbacks' then perc95_value_per_sec
            end user_rollbacks_perc95,
            case
                when stat_name = 'user rollbacks' then perc100_value_per_sec
            end user_rollbacks_perc100
        from
            v_dbahistsysstat a
    ),
    vsysstat_part2 as (
        select
            b.info_source,
            b.pkey,
            b.dbid,
            b.instance_number,
            b.hour,
            sum(cpu_used_by_this_session_perc50) cpu_used_by_this_session_perc50,
            sum(cpu_used_by_this_session_perc75) cpu_used_by_this_session_perc75,
            sum(cpu_used_by_this_session_perc95) cpu_used_by_this_session_perc95,
            sum(cpu_used_by_this_session_perc100) cpu_used_by_this_session_perc100,
            sum(dbtime_perc50) dbtime_perc50,
            sum(dbtime_perc75) dbtime_perc75,
            sum(dbtime_perc95) dbtime_perc95,
            sum(dbtime_perc100) dbtime_perc100,
            sum(cellflashcachereadhit_perc50) cellflashcachereadhit_perc50,
            sum(cellflashcachereadhit_perc75) cellflashcachereadhit_perc75,
            sum(cellflashcachereadhit_perc95) cellflashcachereadhit_perc95,
            sum(cellflashcachereadhit_perc100) cellflashcachereadhit_perc100,
            sum(cell_inter_bytes_returned_by_XT_smartscan_perc50) cell_inter_bytes_returned_by_XT_smartscan_perc50,
            sum(cell_inter_bytes_returned_by_XT_smartscan_perc75) cell_inter_bytes_returned_by_XT_smartscan_perc75,
            sum(cell_inter_bytes_returned_by_XT_smartscan_perc95) cell_inter_bytes_returned_by_XT_smartscan_perc95,
            sum(
                cell_inter_bytes_returned_by_XT_smartscan_perc100
            ) cell_inter_bytes_returned_by_XT_smartscan_perc100,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc50
            ) cell_io_bytes_eligible_for_predicate_offload_perc50,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc75
            ) cell_io_bytes_eligible_for_predicate_offload_perc75,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc95
            ) cell_io_bytes_eligible_for_predicate_offload_perc95,
            sum(
                cell_io_bytes_eligible_for_predicate_offload_perc100
            ) cell_io_bytes_eligible_for_predicate_offload_perc100,
            sum(cell_io_bytes_eligible_for_smartios_perc50) cell_io_bytes_eligible_for_smartios_perc50,
            sum(cell_io_bytes_eligible_for_smartios_perc75) cell_io_bytes_eligible_for_smartios_perc75,
            sum(cell_io_bytes_eligible_for_smartios_perc95) cell_io_bytes_eligible_for_smartios_perc95,
            sum(cell_io_bytes_eligible_for_smartios_perc100) cell_io_bytes_eligible_for_smartios_perc100,
            sum(cell_io_bytes_saved_by_storage_index_perc50) cell_io_bytes_saved_by_storage_index_perc50,
            sum(cell_io_bytes_saved_by_storage_index_perc75) cell_io_bytes_saved_by_storage_index_perc75,
            sum(cell_io_bytes_saved_by_storage_index_perc95) cell_io_bytes_saved_by_storage_index_perc95,
            sum(cell_io_bytes_saved_by_storage_index_perc100) cell_io_bytes_saved_by_storage_index_perc100,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc50,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc75,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc95,
            sum(
                cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100
            ) cell_io_bytes_sent_directly_to_dbnode_to_balance_cpu_perc100,
            sum(cell_io_interconnect_bytes_perc50) cell_io_interconnect_bytes_perc50,
            sum(cell_io_interconnect_bytes_perc75) cell_io_interconnect_bytes_perc75,
            sum(cell_io_interconnect_bytes_perc95) cell_io_interconnect_bytes_perc95,
            sum(cell_io_interconnect_bytes_perc100) cell_io_interconnect_bytes_perc100,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc50
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc50,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc75
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc75,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc95
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc95,
            sum(
                cell_io_interconnect_bytes_returned_by_smartcan_perc100
            ) cell_io_interconnect_bytes_returned_by_smartcan_perc100,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc50
            ) cell_physical_write_io_bytes_eligible_for_offload_perc50,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc75
            ) cell_physical_write_io_bytes_eligible_for_offload_perc75,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc95
            ) cell_physical_write_io_bytes_eligible_for_offload_perc95,
            sum(
                cell_physical_write_io_bytes_eligible_for_offload_perc100
            ) cell_physical_write_io_bytes_eligible_for_offload_perc100,
            sum(cell_pmem_cache_read_hits_perc50) cell_pmem_cache_read_hits_perc50,
            sum(cell_pmem_cache_read_hits_perc75) cell_pmem_cache_read_hits_perc75,
            sum(cell_pmem_cache_read_hits_perc95) cell_pmem_cache_read_hits_perc95,
            sum(cell_pmem_cache_read_hits_perc100) cell_pmem_cache_read_hits_perc100,
            sum(dbblockgets_perc50) dbblockgets_perc50,
            sum(dbblockgets_perc75) dbblockgets_perc75,
            sum(dbblockgets_perc95) dbblockgets_perc95,
            sum(execute_count_perc50) execute_count_perc50,
            sum(execute_count_perc75) execute_count_perc75,
            sum(execute_count_perc95) execute_count_perc95,
            sum(execute_count_perc100) execute_count_perc100,
            sum(physical_read_io_requests_perc50) physical_read_io_requests_perc50,
            sum(physical_read_io_requests_perc75) physical_read_io_requests_perc75,
            sum(physical_read_io_requests_perc95) physical_read_io_requests_perc95,
            sum(physical_read_io_requests_perc100) physical_read_io_requests_perc100,
            sum(physical_read_bytes_perc50) physical_read_bytes_perc50,
            sum(physical_read_bytes_perc75) physical_read_bytes_perc75,
            sum(physical_read_bytes_perc95) physical_read_bytes_perc95,
            sum(physical_read_bytes_perc100) physical_read_bytes_perc100,
            sum(physical_read_flash_cache_hits_perc50) physical_read_flash_cache_hits_perc50,
            sum(physical_read_flash_cache_hits_perc75) physical_read_flash_cache_hits_perc75,
            sum(physical_read_flash_cache_hits_perc95) physical_read_flash_cache_hits_perc95,
            sum(physical_read_flash_cache_hits_perc100) physical_read_flash_cache_hits_perc100,
            sum(physical_read_total_io_requests_perc50) physical_read_total_io_requests_perc50,
            sum(physical_read_total_io_requests_perc75) physical_read_total_io_requests_perc75,
            sum(physical_read_total_io_requests_perc95) physical_read_total_io_requests_perc95,
            sum(physical_read_total_io_requests_perc100) physical_read_total_io_requests_perc100,
            sum(physical_read_total_bytes_perc50) physical_read_total_bytes_perc50,
            sum(physical_read_total_bytes_perc75) physical_read_total_bytes_perc75,
            sum(physical_read_total_bytes_perc95) physical_read_total_bytes_perc95,
            sum(physical_read_total_bytes_perc100) physical_read_total_bytes_perc100,
            sum(physical_reads_perc50) physical_reads_perc50,
            sum(physical_reads_perc75) physical_reads_perc75,
            sum(physical_reads_perc95) physical_reads_perc95,
            sum(physical_reads_perc100) physical_reads_perc100,
            sum(physical_reads_direct_perc50) physical_reads_direct_perc50,
            sum(physical_reads_direct_perc75) physical_reads_direct_perc75,
            sum(physical_reads_direct_perc95) physical_reads_direct_perc95,
            sum(physical_reads_direct_perc100) physical_reads_direct_perc100,
            sum(physical_reads_direct_lob_perc50) physical_reads_direct_lob_perc50,
            sum(physical_reads_direct_lob_perc75) physical_reads_direct_lob_perc75,
            sum(physical_reads_direct_lob_perc95) physical_reads_direct_lob_perc95,
            sum(physical_reads_direct_lob_perc100) physical_reads_direct_lob_perc100,
            sum(physical_write_io_req_perc50) physical_write_io_req_perc50,
            sum(physical_write_io_req_perc75) physical_write_io_req_perc75,
            sum(physical_write_io_req_perc95) physical_write_io_req_perc95,
            sum(physical_write_io_req_perc100) physical_write_io_req_perc100,
            sum(physical_write_bytes_perc50) physical_write_bytes_perc50,
            sum(physical_write_bytes_perc75) physical_write_bytes_perc75,
            sum(physical_write_bytes_perc95) physical_write_bytes_perc95,
            sum(physical_write_bytes_perc100) physical_write_bytes_perc100,
            sum(physical_write_total_io_req_perc50) physical_write_total_io_req_perc50,
            sum(physical_write_total_io_req_perc75) physical_write_total_io_req_perc75,
            sum(physical_write_total_io_req_perc95) physical_write_total_io_req_perc95,
            sum(physical_write_total_io_req_perc100) physical_write_total_io_req_perc100,
            sum(physical_write_total_bytes_perc50) physical_write_total_bytes_perc50,
            sum(physical_write_total_bytes_perc75) physical_write_total_bytes_perc75,
            sum(physical_write_total_bytes_perc95) physical_write_total_bytes_perc95,
            sum(physical_write_total_bytes_perc100) physical_write_total_bytes_perc100,
            sum(physical_writes_perc50) physical_writes_perc50,
            sum(physical_writes_perc75) physical_writes_perc75,
            sum(physical_writes_perc95) physical_writes_perc95,
            sum(physical_writes_perc100) physical_writes_perc100,
            sum(physical_writes_direct_lob_perc50) physical_writes_direct_lob_perc50,
            sum(physical_writes_direct_lob_perc75) physical_writes_direct_lob_perc75,
            sum(physical_writes_direct_lob_perc95) physical_writes_direct_lob_perc95,
            sum(physical_writes_direct_lob_perc100) physical_writes_direct_lob_perc100,
            sum(recursive_cpu_usage_perc50) recursive_cpu_usage_perc50,
            sum(recursive_cpu_usage_perc75) recursive_cpu_usage_perc75,
            sum(recursive_cpu_usage_perc95) recursive_cpu_usage_perc95,
            sum(recursive_cpu_usage_perc100) recursive_cpu_usage_perc100,
            sum(user_io_wait_time_perc50) user_io_wait_time_perc50,
            sum(user_io_wait_time_perc75) user_io_wait_time_perc75,
            sum(user_io_wait_time_perc95) user_io_wait_time_perc95,
            sum(user_io_wait_time_perc100) user_io_wait_time_perc100,
            sum(user_calls_perc50) user_calls_perc50,
            sum(user_calls_perc75) user_calls_perc75,
            sum(user_calls_perc95) user_calls_perc95,
            sum(user_calls_perc100) user_calls_perc100,
            sum(user_commits_perc50) user_commits_perc50,
            sum(user_commits_perc75) user_commits_perc75,
            sum(user_commits_perc95) user_commits_perc95,
            sum(user_commits_perc100) user_commits_perc100,
            sum(user_rollbacks_perc50) user_rollbacks_perc50,
            sum(user_rollbacks_perc75) user_rollbacks_perc75,
            sum(user_rollbacks_perc95) user_rollbacks_perc95,
            sum(user_rollbacks_perc100) user_rollbacks_perc100
        from
            vsysstat_part1 b
        group by
            b.info_source,
            b.pkey,
            b.dbid,
            b.instance_number,
            b.hour
    )
select
    d.db_version as dbversion,
    'All Metrics are Per Second' metric_unit,
    c.*
from
    vsysstat_part2 c
    inner join dbsummary d on c.pkey = d.pkey
    and c.dbid = d.dbid;