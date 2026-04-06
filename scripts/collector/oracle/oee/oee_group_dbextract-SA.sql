REM /***************************************
REM * Copyright (c) 2024 Oracle and/or its affiliates.
REM * Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
REM ***************************************
REM * OEE Group Extract StandAlone v5.1
REM ****************************************
REM SQLPLUS Environment Options that help format the output of MPACK
REM ================================================================================================
        SET LONG 99999999
        -- added an extra 9 for long that should allow clob to be ~10 times bigger and avoid concatenetaed results 
        set longchunksize 99999999
        -- added an extra 9 for longchunksize that should allow clob to be ~10 times bigger and avoid concatenetaed results 
        set echo OFF
        set feed OFF
        set lines 20000
        set head off
        -- set pages 3000
        set serveroutput OFF
        set trimspool ON

        ALTER SESSION SET NLS_LANGUAGE = 'AMERICAN';
        ALTER SESSION SET NLS_NUMERIC_CHARACTERS = '.,' ;
        ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';


REM A SET OF SQLPLUS CLOB VARIABLES THAT WILL RECEIVE THE OUTPUT OF EACH SECTION OF THE MPACK EXTRACT
REM =================================================================================================
        VARIABLE mpack_database CLOB
        VARIABLE mpack_basic_lobs CLOB
        VARIABLE mpack_clustered_tables CLOB
        VARIABLE mpack_rowid_columns CLOB
        VARIABLE mpack_media_columns CLOB
        VARIABLE mpack_external_tables CLOB
        VARIABLE mpack_iots CLOB
        VARIABLE mpack_java_objects CLOB
        VARIABLE mpack_ilm_policies CLOB
        VARIABLE mpack_incompatible_jobs CLOB
        VARIABLE mpack_restricted_packages CLOB
        VARIABLE mpack_dba_roles CLOB
        VARIABLE mpack_xmltypes CLOB
        VARIABLE mpack_xmlschema CLOB
        VARIABLE mpack_xmltype_tables CLOB
        VARIABLE mpack_xmldb_objects CLOB
        VARIABLE mpack_spatial_objs CLOB
        VARIABLE mpack_common_objs CLOB
        VARIABLE mpack_no_compression CLOB
        VARIABLE mpack_dblinks CLOB
        VARIABLE mpack_directories CLOB
        VARIABLE mpack_libraries CLOB
        VARIABLE mpack_dba_roles CLOB
        VARIABLE mpack_trusted_server CLOB
        VARIABLE mpack_lcm_user CLOB
        VARIABLE mpack_all_parameters CLOB

REM MAIN MPACK EXTRACT CODE BEGINS HERE
REM ==================================================================================================
        DECLARE

        -- Cursor and variables that hold schemas to exclude from analysis
        l_excluded_schemas SYS.ODCIVARCHAR2LIST;
        v_excluded_schemas varchar2(8000);
        v_oracle_maintained number;

        /* Removed in v5.0 for CPAT alignment
        CURSOR c_oracle_maintained_schema IS
        SELECT NAME AS SCHEMA 
        FROM SYS.KU_NOEXP_VIEW 
        WHERE OBJ_TYPE='SCHEMA' 
        UNION 
        SELECT USERNAME 
        FROM SYS.DBA_USERS 
        WHERE ORACLE_MAINTAINED = 'Y';

        c_oracle_maintained_schema_row c_oracle_maintained_schema%rowtype;

        */

        v_default_excluded_schemas varchar2(5000) := Q'['ANONYMOUS','APEX_030200','APEX_040000','APEX_040100','APEX_040200','APEX_050000','APEX_LISTENER','APEX_PUBLIC_USER','APEX_REST_PUBLIC_USER','APPQOSSYS',
                                                        'AUDSYS','CSMIG','CTXSYS','DBSFWUSER','DBSNMP','DIP','DMSYS','DVF','DVSYS','EXFSYS','FLOWS_030000','FLOWS_030100','FLOWS_040100','FLOWS_FILES','GGSYS',
                                                        'GSMADMIN_INTERNAL','GSMCATUSER','GSMUSER','LBACSYS','MDDATA','MDSYS','MGDSYS','MGMT_VIEW','OJVMSYS','OLAPSYS','ORACLE_OCM','ORDDATA','ORDPLUGINS','ORDSYS',
                                                        'OUTLN','OWBSYS','REMOTE_SCHEDULER_AGENT','SI_INFORMTN_SCHEMA','SPATIAL_CSW_ADMIN_USR','SPATIAL_WFS_ADMIN_USR','SYS','SYS$UMF','SYSBACKUP','SYSDG','SYSKM','SYSMAN',
                                                        'SYSRAC','SYSTEM','TSMSYS','WKPROXY','WKSYS','WK_TEST','WMSYS','XDB','XS$NULL']';

        -- Cursor to retrieve values from v$database
        CURSOR c_database IS
        SELECT DBID,
            NAME,
            LOG_MODE,
            CONTROLFILE_TYPE,
            OPEN_MODE,
            PROTECTION_LEVEL,
            DATABASE_ROLE,
            DATAGUARD_BROKER,
            case
                when
                    SUPPLEMENTAL_LOG_DATA_MIN='YES'
                or SUPPLEMENTAL_LOG_DATA_PK='YES'
                or SUPPLEMENTAL_LOG_DATA_UI='YES'
                or SUPPLEMENTAL_LOG_DATA_FK='YES'
                or SUPPLEMENTAL_LOG_DATA_ALL='YES'
                then 'YES'
                else 'NO'
            end SUPPLEMENTAL_LOGGING,
            FORCE_LOGGING,
            PLATFORM_NAME,
            FLASHBACK_ON
        FROM v$database;

        c_database_row c_database%rowtype;

        -- Dynamic SQL Cursor to determine whether a >= 12c database is multitenant or not
        c_multitenant_flag_sql varchar2(500):='SELECT CDB FROM V$DATABASE';
        c_multitenant_flag_value varchar2(3);

        -- Dyanmic SQL Cursor used to obtain PDB rather than CDB values for database identification
        c_database_sql varchar2(500):='SELECT DBID,NAME FROM v$PDBS';
        c_database_sql_dbid number:=null;
        c_database_sql_name varchar2(50);

        -- Cursor to retrieve values from v$instance
        CURSOR c_instance IS
        SELECT INSTANCE_NUMBER,
                INSTANCE_NAME,
                HOST_NAME,
                VERSION
            FROM v$instance;  

        c_instance_row c_instance%rowtype;

        -- Cursor to retrieve values from dba_registry
        CURSOR c_registry IS
        SELECT max(case when COMP_ID='OWB' then STATUS else '*NOTPRESENT*' end) WAREHOUSE_BUILDER_STATUS,
            max(case when COMP_ID='AMD' then STATUS else '*NOTPRESENT*' end) OLAP_STATUS,
            max(case when COMP_ID='SDO' then STATUS else '*NOTPRESENT*' end) SPATIAL_STATUS,
            max(case when COMP_ID='ORDIM' then STATUS else '*NOTPRESENT*' end) MULTIMEDIA_STATUS,
            max(case when COMP_ID='XDB' then STATUS else '*NOTPRESENT*' end) XMLDB_STATUS,
            max(case when COMP_ID='CONTEXT' then STATUS else '*NOTPRESENT*' end) TEXT_STATUS,
            max(case when COMP_ID='EXF' then STATUS else '*NOTPRESENT*' end) EXPRESSION_FILTER_STATUS,
            max(case when COMP_ID='RUL' then STATUS else '*NOTPRESENT*' end) RULES_MANAGER_STATUS,
            max(case when COMP_ID='OWM' then STATUS else '*NOTPRESENT*' end) WORKSPACE_MANAGER_STATUS,
            max(case when COMP_ID='CATALOG' THEN STATUS else '*NOTPRESENT*' end) CATALOG_STATUS,
            max(case when COMP_ID='CATPROC' THEN STATUS else '*NOTPRESENT*' end) CATPROC_STATUS,
            max(case when COMP_ID='JAVAVM' THEN STATUS else '*NOTPRESENT*' end) JAVAVM_STATUS,
            max(case when COMP_ID='XML' THEN STATUS else '*NOTPRESENT*' end) XML_DEVELOPER_KIT_STATUS,
            max(case when COMP_ID='CATJAVA' THEN STATUS else '*NOTPRESENT*' end) JAVA_CATALOG_STATUS,
            max(case when COMP_ID='APS' THEN STATUS else '*NOTPRESENT*' end) ANALYTICS_WS_STATUS,
            max(case when COMP_ID='XOQ' THEN STATUS else '*NOTPRESENT*' end) OLAP_API_STATUS,
            max(case when COMP_ID='RAC' THEN STATUS else '*NOTPRESENT*' end) RAC_STATUS,
            max(case when COMP_ID='OLS' THEN STATUS else '*NOTPRESENT*' end) LABEL_SECURITY_STATUS,
            max(case when COMP_ID='DV' THEN STATUS else '*NOTPRESENT*' end) DATA_VAULT_STATUS
        FROM dba_registry;

        c_registry_row c_registry%rowtype;

        -- Cursor to retrieve values from v$parameter
        CURSOR c_parameter IS
        SELECT max(case when name='cpu_count' then value else null end) "CPU",
            max(case when name='cpu_count' then ismodified else null end) "CPU_MODIFIED",
            max(case when name='sga_target' then value else null end) "SGA",
            max(case when name='sga_target' then ismodified else null end) "SGA_MODIFIED",
            max(case when name='sga_max_size' then value else null end) "SGA_MAX",
            max(case when name='sga_max_size' then ismodified else null end) "SGA_MAX_MODIFIED",
            max(case when name='memory_target' then value else null end) "MEMORY",
            max(case when name='memory_target' then ismodified else null end) "MEMORY_MODIFIED",
            max(case when name='memory_max_target' then value else null end) "MEMORY_MAX",
            max(case when name='memory_max_target' then ismodified else null end) "MEMORY_MAX_MODIFIED",
            max(case when name='pga_aggregate_target' then value else null end) "PGA",
            max(case when name='pga_aggregate_target' then ismodified else null end) "PGA_MODIFIED",
            max(case when name='pga_aggregate_limit' then value else null end) "PGA_MAX",
            max(case when name='pga_aggregate_limit' then ismodified else null end) "PGA_MAX_MODIFIED",
            max(case when name='shared_pool_size' then value else null end) "SHARED_POOL",
            max(case when name='shared_pool_size' then ismodified else null end) "SHARED_POOL_MODIFIED",
            max(case when name='db_cache_size' then value else null end) "CACHE_SIZE",
            max(case when name='db_cache_size' then ismodified else null end) "CACHE_SIZE_MODIFIED",
            max(case when name='db_block_buffers' then value else null end) "BLOCK_BUFFERS",
            max(case when name='db_block_buffers' then ismodified else null end) "BLOCK_BUFFERS_MODIFIED",
            max(case when name='db_keep_cache_size' then value else null end) "KEEP_CACHE",
            max(case when name='db_keep_cache_size' then ismodified else null end) "KEEP_CACHE_MODIFIED",
            max(case when name='db_recycle_cache_size' then value else null end) "RECYCLE_CACHE",
            max(case when name='db_recycle_cache_size' then ismodified else null end) "RECYCLE_CACHE_MODIFIED",
            max(case when name='streams_pool_size' then value else null end) "STREAMS_POOL",
            max(case when name='streams_pool_size' then ismodified else null end) "STREAMS_POOL_MODIFIED",
            max(case when name='log_buffer' then value else null end) "LOG_BUFFER",
            max(case when name='log_buffer' then ismodified else null end) "LOG_BUFFER_MODIFIED",
            max(case when name='inmemory_size' then value else null end) "INMEMORY",
            max(case when name='inmemory_size' then ismodified else null end) "INMEMORY_MODIFIED",
            max(case when name='dispatchers' then value else null end) "DISPATCHERS",
            max(case when name='dispatchers' then ismodified else null end) "DISPATCHERS_MODIFIED",
            max(case when name='max_dispatchers' then value else null end) "DISPATCHERS#",
            max(case when name='max_dispatchers' then ismodified else null end) "DISPATCHERS#_MODIFIED",
            max(case when name='shared_servers' then value else null end) "SHARED_SERVERS",
            max(case when name='shared_servers' then ismodified else null end) "SHARED_SERVERS_MODIFIED",
            max(case when name='parallel_degree_policy' then value else null end) "PARALLEL_POLICY",
            max(case when name='parallel_degree_policy' then ismodified else null end) "PARALLEL_POLICY_MODIFIED",
            max(case when name='parallel_degree_limit' then value else null end) "PARALLEL_DEGREE",
            max(case when name='parallel_degree_limit' then ismodified else null end) "PARALLEL_DEGREE_MODIFIED",
            max(case when name='parallel_max_servers' then value else null end) "PARALLEL_SERVERS#",
            max(case when name='parallel_max_servers' then ismodified else null end) "PARALLEL_SERVERS#_MODIFIED",
            max(case when name='parallel_servers_target' then value else null end) "PARALLEL_SVR_TGT",
            max(case when name='parallel_servers_target' then ismodified else null end) "PARALLEL_SVR_TGT_MODIFIED",
            max(case when name='parallel_threads_per_cpu' then value else null end) "PARALLEL_CPU",
            max(case when name='parallel_threads_per_cpu' then ismodified else null end) "PARALLEL_CPU_MODIFIED"
        FROM v$parameter;

        c_parameter_row c_parameter%rowtype;

        -- CURSOR TO FETCH ALL PARAMETERS
        CURSOR c_all_parameters IS
        SELECT 
            name,
            type,
            SUBSTR(
                REGEXP_REPLACE(
                    REGEXP_REPLACE(value, CHR(10) || '|' || CHR(9), ' '),
                    '\s+',
                    ' '
                ),
                1,
                32000
            ) AS value,
            isdefault,
            ismodified,
            isdeprecated,
            description
        FROM v$parameter;


        c_all_parameters_row c_all_parameters%rowtype;

        -- Cursor to retrieve calculated database size from dba_data_files
        CURSOR c_db_size IS
        SELECT round(sum(used_ts_size)/1024, 2) "TOTAL_USED_DB_SIZE_GB",
            round(sum(curr_ts_size)/1024, 2) "TOTAL_CURRENT_DB_SIZE_GB",
            round(sum(max_ts_size)/1024, 2) "TOTAL_MAX_ALLOCATED_DB_SIZE_GB"
        FROM
            (SELECT df.tablespace_name, 
                    (df.bytes - sum(fs.bytes)) / (1024 * 1024) used_ts_size,
                    df.bytes / (1024 * 1024) curr_ts_size,
                    df.maxbytes / (1024 * 1024) max_ts_size
                FROM dba_free_space fs,
                    (SELECT tablespace_name,
                            sum(bytes) bytes,
                            sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes
                        FROM dba_data_files
                        GROUP BY tablespace_name) df   
                WHERE fs.tablespace_name (+) = df.tablespace_name
                GROUP BY df.tablespace_name,
                        df.bytes,
                        df.maxbytes);

        c_db_size_row c_db_size%rowtype;

        -- Cursor to ascertain whether block_change_tracking is enabled
        CURSOR c_block_change_tracking IS
        SELECT max(STATUS) AS STATUS
        FROM v$block_change_tracking;

        c_block_change_tracking_row c_block_change_tracking%rowtype;

        -- Cursor to identify whether encrypted columns are in use
        CURSOR c_encrypted_columns IS
        SELECT COUNT(*) TOTAL_COLS
        FROM dba_encrypted_columns;

        c_encrypted_columns_row  c_encrypted_columns%rowtype;

        -- Cursor to retrieve nls characterset
        CURSOR c_nls IS
        SELECT value 
        FROM v$nls_parameters
        WHERE parameter='NLS_CHARACTERSET';

        c_nls_row c_nls%rowtype;

        -- Cursor to retrieve national characterset
        CURSOR c_national_char IS
        SELECT value 
        FROM v$nls_parameters
        WHERE parameter='NLS_NCHAR_CHARACTERSET';

        c_national_char_row c_national_char%rowtype;

        -- Cursor to establish the maximum number of sessions ever seen in the database
        CURSOR c_max_sessions IS
        SELECT highwater 
        FROM dba_high_water_mark_statistics
        WHERE name='SESSIONS';

        c_max_sessions_row c_max_sessions%rowtype;

        -- Cursor to establish how many active session there are on average
        CURSOR c_avg_active IS
        SELECT highwater 
        FROM dba_high_water_mark_statistics
        WHERE name='ACTIVE_SESSIONS';

        c_avg_active_row c_avg_active%rowtype;

        -- CPAT check for the use of BASIC LOB files (handled by dynamic SQL later in code)
        c_lobs_sql varchar2(5000);
        c_lobs_owner varchar2(200):= null;
        c_lobs_table_name varchar2(200):=null;
        c_lobs_column_name varchar2(200):=null;

        -- CPAT Cursor to check for the use of clustered tables
        CURSOR c_cpat_clustered_tables IS
        SELECT OWNER, 
            TABLE_NAME
        FROM DBA_TABLES  
        WHERE CLUSTER_NAME IS NOT NULL
        AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas));

        c_cpat_clustered_tables_row c_cpat_clustered_tables%rowtype;

        -- CPAT Cursor to check for the use of rowid's in column definitions
        CURSOR c_cpat_rowids IS
        SELECT a.OWNER, 
            a.TABLE_NAME, 
            a.COLUMN_NAME
        FROM DBA_TAB_COLS a  
        WHERE a.DATA_TYPE = 'ROWID'
        AND a.OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
        AND NOT EXISTS (SELECT 1 FROM DBA_VIEWS WHERE OWNER=a.OWNER and VIEW_NAME=a.TABLE_NAME)
        AND SUBSTR(a.TABLE_NAME,1,4) NOT IN ('AQ$_','BIN$');

        c_cpat_rowids_row c_cpat_rowids%rowtype;

        -- CPAT Cursor to check for the use of media data types
        CURSOR c_cpat_media IS
        SELECT OWNER, 
            TABLE_NAME, 
            COLUMN_NAME, 
            DATA_TYPE
        FROM DBA_TAB_COLUMNS 
        WHERE DATA_TYPE IN ('ORDIMAGE','ORDIMAGESIGNATURE','ORDAUDIO','ORDVIDEO', 'ORDDOC','ORDSOURCE',
                            'ORDDICOM','ORDDATASOURCE', 'SI_STILLIMAGE','SI_COLOR','SI_AVERAGECOLOR', 
                            'SI_POSITIONALCOLOR','SI_TEXTURE','SI_COLORHISTOGRAM', 'SI_FEATURELIST')  
            AND DATA_TYPE_OWNER IN ('ORDSYS', 'PUBLIC')
            AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas));

        c_cpat_media_row c_cpat_media%rowtype;

        -- CPAT Cursor to check for the use of external tables
        CURSOR c_cpat_external_tabs IS
        SELECT OWNER,
            TABLE_NAME,
            TYPE_OWNER,
            TYPE_NAME,
            DEFAULT_DIRECTORY_OWNER,
            DEFAULT_DIRECTORY_NAME
        FROM DBA_EXTERNAL_TABLES
        WHERE OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas));

        c_cpat_external_tabs_row c_cpat_external_tabs%rowtype;

        -- CPAT Cursor to check for the use of index-organized tables
        CURSOR c_cpat_iots IS
        SELECT OWNER, 
            TABLE_NAME
        FROM DBA_ALL_TABLES  
        WHERE IOT_TYPE='IOT' 
        AND TABLE_NAME NOT LIKE 'AQ$%'  
        AND TABLE_NAME NOT LIKE 'DR$%'  
        AND TABLE_NAME NOT LIKE 'DM$%'
        AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas));

        c_cpat_iots_row c_cpat_iots%rowtype;    

        -- CPAT Cursor to check for the use of java within the database
        CURSOR c_cpat_java_objects IS
        SELECT owner,
            object_name, 
            object_type, 
            status
        FROM dba_objects 
        WHERE (object_name NOT LIKE 'SYS_%' 
                AND object_name NOT LIKE 'CREATE$%' 
                AND object_name NOT LIKE 'JAVA$%' 
                AND object_name NOT LIKE 'LOADLOB%') 
        AND OBJECT_TYPE IN ('JAVA CLASS', 'JAVA RESOURCES', 'JAVA DATA')
        AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas));

        c_cpat_java_objects_row c_cpat_java_objects%rowtype;

        -- Dyanmic SQL Cursor to check for the use of information lifecycle management policies
        c_ilm_policies_sql VARCHAR2(500):='SELECT OBJECT_OWNER,POLICY_NAME,OBJECT_NAME,OBJECT_TYPE FROM DBA_ILMOBJECTS WHERE OBJECT_TYPE = ''TABLE''  AND ENABLED = ''YES''';
        c_ilm_sql_object_owner varchar2(200):=null;
        c_ilm_sql_policy_name varchar2(200):=null;
        c_ilm_sql_object_name varchar2(200):=null;
        c_ilm_sql_object_type varchar2(200):=null;

        -- CPAT Cursor to check for the use of jobs not written in PL/SQL
        CURSOR c_cpat_incompatible_jobs IS
        SELECT OWNER, 
            NAME, 
            TYPE, 
            LOCUS
        FROM (SELECT OWNER, 
                    JOB_NAME AS NAME, 
                    JOB_TYPE AS TYPE, 
                    'DBA_SCHEDULER_JOBS' AS LOCUS     
                FROM DBA_SCHEDULER_JOBS  
                WHERE JOB_TYPE NOT IN ('STORED_PROCEDURE','PLSQL_BLOCK')  
                AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
                UNION ALL   
                SELECT OWNER, 
                    PROGRAM_NAME AS NAME, 
                    PROGRAM_TYPE AS TYPE, 
                    'DBA_SCHEDULER_PROGRAMS' AS LOCUS     
                FROM DBA_SCHEDULER_PROGRAMS  
                WHERE PROGRAM_TYPE NOT IN ('STORED_PROCEDURE','PLSQL_BLOCK') 
                AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
                );        

        c_cpat_incompatible_jobs_row c_cpat_incompatible_jobs%rowtype;   

        -- CPAT Cursor to check for references to restricted Oracle packages
        CURSOR c_cpat_restricted_packages IS

        SELECT OWNER, 
            NAME, 
            TYPE, 
            REFERENCED_NAME, 
            SUPPORT
        FROM (SELECT OWNER, 
                    NAME, 
                    TYPE, 
                    REFERENCED_NAME, 
                    'UNSUPPORTED' AS SUPPORT 
                FROM DBA_DEPENDENCIES 
                WHERE REFERENCED_NAME IN ('DBMS_DEBUG_JDWP','DBMS_DEBUG_JDWP_CUSTOM','UTL_INADDR','DBMS_SYSTEM','DBMS_SYS_SQL')   
                AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
                UNION ALL  
                SELECT OWNER, 
                    NAME, 
                    TYPE, 
                    REFERENCED_NAME, 
                    'PARTIALLY SUPPORTED' AS SUPPORT 
                FROM DBA_DEPENDENCIES 
                WHERE REFERENCED_NAME IN ('UTL_HTTP','UTL_SMTP','UTL_TCP','DBMS_SHARED_POOL','DBMS_PIPE','DBMS_LDAP','DBMS_NETWORK_ACL_ADMIN')
                AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
                ) 
        WHERE OWNER <> 'PUBLIC' 
        AND TYPE <> 'SYNONYM' 
        AND NAME <> REFERENCED_NAME;

        c_cpat_restricted_packages_row   c_cpat_restricted_packages%rowtype;  


        -- Cursor to check for users granted dba privileges

        /* Pre v5.0 Cursor
        CURSOR c_cpat_dba_roles IS
        SELECT GRANTEE, 
            GRANTED_ROLE 
        FROM DBA_ROLE_PRIVS  
        WHERE GRANTED_ROLE <> 'SQLT_USER_ROLE'  
        AND GRANTED_ROLE  IN ('DBA')
        AND GRANTEE NOT IN ('SYS','SYSTEM');
        */

        -- v5.0 CPAT aligned cursor
        CURSOR c_cpat_dba_roles IS
        SELECT GRANTEE, GRANTED_ROLE 
        FROM (SELECT DISTINCT CONNECT_BY_ROOT GRANTEE AS GRANTEE, 
                                GRANTED_ROLE    
                FROM SYS.DBA_ROLE_PRIVS  
                START WITH GRANTEE NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))  
            CONNECT BY GRANTEE = PRIOR GRANTED_ROLE)  
        WHERE GRANTEE NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
        AND GRANTEE IN (SELECT USERNAME FROM SYS.DBA_USERS)  
        AND GRANTED_ROLE <> 'SQLT_USER_ROLE'  
        AND GRANTED_ROLE IN ('EXP_FULL_DATABASE','JAVAUSERPRIV','XDB_SET_INVOKER','JAVA_ADMIN','XDBADMIN','DBA','RECOVERY_CATALOG_USER',
                            'SCHEDULER_ADMIN','EM_EXPRESS_ALL','EM_EXPRESS_BASIC','EXECUTE_CATALOG_ROLE','DATAPUMP_EXP_FULL_DATABASE',
                            'IMP_FULL_DATABASE','HS_ADMIN_EXECUTE_ROLE','XS_RESOURCE','JAVA_DEPLOY','OLAP_DBA','DATAPUMP_IMP_FULL_DATABASE',
                            'DELETE_CATALOG_ROLE','OLAP_XS_ADMIN','WM_ADMIN_ROLE');

        c_cpat_dba_roles_row c_cpat_dba_roles%rowtype;

        -- Cursor to obtain count of objects in the XML DB Repository
        l_xml_queryA varchar2(4000):='SELECT COUNT(*) AS COUNTER
                                        FROM RESOURCE_VIEW';

        TYPE l_xml_queryA_rec IS RECORD (COUNTER NUMBER);
        TYPE l_xml_queryA_tab is TABLE OF l_xml_queryA_rec;
        l_xml_queryA_collection l_xml_queryA_tab;

        -- Cursor to check for use of XMLType Tables
        l_xml_queryB varchar2(4000);
        TYPE l_xml_queryB_rec is RECORD (DXT_OWNER        VARCHAR2(128),
                                        DXT_TABLE_NAME   VARCHAR2(128), 
                                        DXT_STORAGE_TYPE VARCHAR2(17));
        TYPE l_xml_queryB_tab is TABLE OF l_xml_queryB_rec;
        l_xml_queryB_collection l_xml_queryB_tab;

        -- Cursor to check for use of XML Schema Objects
        l_xml_queryC varchar2(4000);
        TYPE l_xml_queryC_rec is RECORD (DXS_OWNER        VARCHAR2(128),
                                        DXS_SCHEMA_URL   VARCHAR2(700));
        TYPE l_xml_queryC_tab is TABLE OF l_xml_queryC_rec;
        l_xml_queryC_collection l_xml_queryC_tab;

        -- Cursor to check for use of XMLTYPES
        l_xml_queryD varchar2(4000);
        TYPE l_xml_queryD_rec is RECORD (DXTC_OWNER        VARCHAR2(128),
                                        DXTC_TABLE_NAME   VARCHAR2(128),
                                        DXTC_COLUMN_NAME  VARCHAR2(4000),
                                        DXTC_STORAGE_TYPE VARCHAR2(17),
                                        DXTC_XMLSCHEMA    VARCHAR2(700),
                                        DXTC_SCHEMA_OWNER VARCHAR2(128));
        TYPE l_xml_queryD_tab is TABLE OF l_xml_queryD_rec;
        l_xml_queryD_collection l_xml_queryD_tab;

        -- Cursor variables to check for use of Spatial objects

        c_spatial_sql varchar2(5000);
        c_spatial_sql_owner varchar2(500);
        c_spatial_sql_table_name varchar2(500); 
        c_spatial_sql_column_name varchar2(500); 
        c_spatial_sql_data_type varchar2(500);

        -- Dynamic cursor to check for use of Common Objects

        /* changed in v5.0 for CPAT alignment
        c_common_sql varchar2(500):='SELECT OBJ.OWNER, OBJ.OBJECT_NAME, OBJ.OBJECT_TYPE, OBJ.SHARING, OBJ.APPLICATION '||
                                    'FROM DBA_OBJECTS OBJ '||
                                    'WHERE OBJ.OWNER IN (SELECT USERNAME FROM DBA_USERS '||
                                                        'WHERE ORACLE_MAINTAINED =''N'') '||
                                        'AND OBJ.APPLICATION = ''Y''';
        */

        -- v5.0 statement
        c_common_sql varchar2(1000):='SELECT USERNAME AS OBJECT_NAME, USER AS OBJECT_TYPE '||
                                    'FROM SYS.DBA_USERS WHERE (COMMON=''YES'' OR UPPER(USERNAME) LIKE ''C##%'') '||
                                    'AND ORACLE_MAINTAINED <> ''Y''  AND USERNAME <> ''C##GGADMIN'' UNION ALL '||
                                    'SELECT ROLE AS OBJECT_NAME, ''ROLE'' AS OBJECT_TYPE FROM SYS.DBA_ROLES R '||
                                    'WHERE (COMMON=''YES'' OR UPPER(ROLE) LIKE ''C##%'') AND ORACLE_MAINTAINED <> ''Y''  UNION ALL  '||
                                    'SELECT UNIQUE PROFILE AS OBJECT_NAME, ''PROFILE'' AS OBJECT_TYPE FROM SYS.DBA_PROFILES WHERE COMMON=''YES'' OR UPPER(PROFILE) LIKE ''C##%'' AND '||
                                    'UPPER(PROFILE) NOT IN (''ORA_ADMIN_PROFILE'',''ORA_APP_PROFILE'',''ORA_MANDATORY_PROFILE'')';

        c_common_sql_owner varchar2(500);
        c_common_sql_object_name varchar2(500);
        c_common_sql_object_type varchar2(500);
        c_common_sql_sharing varchar2(500);
        c_common_sql_application varchar2(500);

        -- Cursor to check for tables with disabled compression
        CURSOR c_cpat_no_compression IS
        SELECT OWNER,count(*) NO_COMPRESSION_TABLES
        FROM DBA_TABLES
        WHERE COMPRESSION = 'DISABLED'
            AND OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
        GROUP BY OWNER ORDER BY OWNER;

        c_cpat_no_compression_row  c_cpat_no_compression%rowtype;    

        -- Cursor to check for db links
        CURSOR c_cpat_dblinks IS
        SELECT OWNER,
                DB_LINK,
                regexp_replace(HOST, CHR(10) || '|' || CHR(9), ' ') HOST /* Replacing return character with space in order to keep record in the same line */
        FROM DBA_DB_LINKS
        WHERE OWNER NOT IN (SELECT column_value FROM TABLE(l_excluded_schemas))
        ORDER BY 1,2;

        c_cpat_dblinks_row  c_cpat_dblinks%rowtype;

        -- Cursor to check for directories
        CURSOR c_cpat_directories IS
        SELECT OWNER,
                DIRECTORY_NAME,
                DIRECTORY_PATH
        FROM DBA_DIRECTORIES
        WHERE DIRECTORY_NAME NOT IN
                    ('ORADIR',
                    'SDO_DIR_WORK',
                    'SDO_DIR_ADMIN',
                    'XMLDIR',
                    'XSDDIR',
                    'OPATCH_INST_DIR',
                    'ORACLE_OCM_CONFIG_DIR2',
                    'ORACLE_BASE',
                    'ORACLE_HOME',
                    'ORACLE_OCM_CONFIG_DIR',
                    'DATA_PUMP_DIR',
                    'DBMS_OPTIM_LOGDIR',
                    'DBMS_OPTIM_ADMINDIR',
                    'OPATCH_SCRIPT_DIR',
                    'OPATCH_LOG_DIR',
                    'JAVA$JOX$CUJS$DIRECTORY$')
        ORDER BY 1,2;

        c_cpat_directories_row  c_cpat_directories%rowtype;

        -- Dynamic cursor to check for use of Libraries. Different spec for 11g and 12c onwards
        c_12c_libraries_sql varchar2(5000);
        c_11g_libraries_sql varchar2(5000);
        c_libraries_owner varchar2(500);
        c_libraries_library_name varchar2(500);
        c_libraries_file_spec varchar2(500);
        c_libraries_12c_conid varchar2(500);

        -- Cursor to check for directories
        CURSOR c_cpat_trusted_server IS
        SELECT TRUST,
                NAME
        FROM TRUSTED_SERVERS
        --  WHERE UPPER(NAME) != 'ALL'  * Removed in v5.0 to align with CPAT  
        ORDER BY 1,2;

        c_cpat_trusted_server_row  c_cpat_trusted_server%rowtype;

        CURSOR c_cpat_lcm_user IS
        SELECT 'EXISTS' AS STATUS
            FROM dba_users 
        WHERE username = 'LCM_SUPER_ADMIN';

        c_cpat_lcm_user_row   c_cpat_lcm_user%rowtype; 

        -- SUMMARY CLOBS
        -- ==================================
        -- CLOB variable that stores the summary output for the v$database, v$instance, v$parameter cursors
        -- This CLOB will only ever hold a single row of data. Therefore, there is no risk of exceeding the 32KB limit
        -- associated with directly accessed LOBS. As a result, access to this CLOB is done outside of DBMS_LOB

        mpack_summary CLOB;

        -- DETAIL CLOBS
        -- ===================================
        -- Declare CLOB locators that will each store the detailed output of one CPAT test
        -- Each of these CLOBS may ultimately contain more than one record. In some cases, this could many thousands.
        -- Therefore, these CLOBS will be accessed via the DBMS_LOB package so that more than 32KB of data (max 4GB) can be stored
        -- in each of them. 
        -- For this to be possible, the code will create temporary lobs linked to each of these LOB locators

        cpat_all_parameters CLOB;
        cpat_basic_lobs CLOB;
        cpat_clustered_tables CLOB;
        cpat_rowid_columns CLOB;
        cpat_media_columns CLOB;
        cpat_external_tables CLOB;
        cpat_iots CLOB;
        cpat_java_objects CLOB;
        cpat_ilm_policies CLOB;
        cpat_incompatible_jobs CLOB;
        cpat_restricted_packages CLOB;
        cpat_dba_roles CLOB;
        cpat_xmltypes CLOB;
        cpat_xmlschema CLOB;
        cpat_xmltype_tables CLOB;
        cpat_xmldb_objects CLOB;
        cpat_spatial_objs CLOB;
        cpat_common_objs CLOB;
        cpat_no_compression CLOB;
        cpat_dblinks CLOB;
        cpat_directories CLOB;
        cpat_libraries CLOB;
        cpat_trusted_server CLOB;
        cpat_lcm_user CLOB;

        -- CLOB variable that stores the new row of data to be appended to the summary and detail CLOB's
        new_clob_record CLOB;

        -- LOCAL VARIABLES
        -- =====================================

        -- These variables hold the DBID and Database Name. They are by one of two cursors depending on whether the database is a pluggable database or not
        v_dbid number;
        v_dbname varchar2(50);

        -- Variables that hold the count of exception records against each of the CPAT tests
        -- These counters are included in the Database Summary Record
        v_basic_lobs_rows number:=0;
        v_clustered_tables_rows number:=0;
        v_rowid_columns_rows number:=0;
        v_media_columns_rows number:=0;
        v_external_tables_rows number:=0;
        v_iots_rows number:=0;
        v_java_objects_rows number:=0;
        v_ilm_policies_rows number:=0;
        v_incompatible_jobs_rows number:=0;
        v_restricted_packages_rows number:=0;
        v_dba_roles_rows number:=0;
        v_xmltypes_rows number:=0;
        v_xmlschema_rows number:=0;
        v_xmltype_tables_rows number:=0;
        v_xmldb_objects_rows number:=0;
        v_spatial_obj_rows number:=0;
        v_common_obj_rows number:=0;
        v_no_compression_rows number:=0;
        v_dblinks_rows number:=0;
        v_directories_rows number:=0;
        v_libraries_rows number:=0;
        v_trusted_server_rows number:=0;
        v_lcm_user_rows number:=0;

        l_xml_check   varchar2(1):='Y';
        -- 11g additions
        -- for where XML Tables don't exist
        l_xml_check2  varchar2(1):='Y';
        l_xmltypes_count number:=0;
        l_xml_check3  varchar2(1):='Y';
        l_xmlschema_count number:=0;
        l_xml_check4  varchar2(1):='Y';
        l_xmltable_count number:=0;

        -- Structures used to execute dynamic sql where necessary. Usually due to differences between 11g and multi-tenant databases.
        v_dynsql varchar2(32000);
        TYPE dyncur  IS REF CURSOR;
        v_dyn_cursor    dyncur;

        -- v_extract_date_time is used in conjunction with the DBID to create a primary key identifier for this extract
        v_extract_date_time varchar2(20);


        FUNCTION split_string_to_list(
        p_string IN VARCHAR2,
        p_delim  IN VARCHAR2 := ','
        ) RETURN SYS.ODCIVARCHAR2LIST
        IS
        l_list SYS.ODCIVARCHAR2LIST := SYS.ODCIVARCHAR2LIST();
        l_start PLS_INTEGER := 1;
        l_end   PLS_INTEGER;
        l_token VARCHAR2(4000);
        v_string VARCHAR2(4000);
        BEGIN
        v_string := REGEXP_REPLACE(p_string, '\s+', '');
        LOOP
            l_end := INSTR(v_string, p_delim, l_start);
            IF l_end = 0 THEN
            l_token := TRIM(SUBSTR(v_string, l_start));
            IF l_token LIKE '''%''' THEN
                l_token := TRIM(BOTH '''' FROM l_token);
            END IF;
            EXIT WHEN l_token IS NULL;
            l_list.EXTEND;
            l_list(l_list.COUNT) := l_token;
            EXIT;
            ELSE
            l_token := TRIM(SUBSTR(v_string, l_start, l_end - l_start));
            IF l_token LIKE '''%''' THEN
                l_token := TRIM(BOTH '''' FROM l_token);
            END IF;
            l_list.EXTEND;
            l_list(l_list.COUNT) := l_token;
            l_start := l_end + 1;
            END IF;
            dbms_output.put_line('list entry = '||l_list(l_list.COUNT));
        END LOOP;
        RETURN l_list;
        END;

        BEGIN

        -- Get the date and time to be used as part of the extract unique identifier
        v_extract_date_time:=to_char(sysdate,'DD-MON-YYYY hh24:mi:ss');

        dbms_lob.createtemporary(mpack_summary, true);
        -- Create the temporary lobs that hold the CPAT detailed results

        dbms_lob.createtemporary(cpat_all_parameters,true); 
        dbms_lob.createtemporary(cpat_basic_lobs,true);
        dbms_lob.createtemporary(cpat_clustered_tables,true);
        dbms_lob.createtemporary(cpat_rowid_columns,true);
        dbms_lob.createtemporary(cpat_media_columns,true);
        dbms_lob.createtemporary(cpat_external_tables,true);
        dbms_lob.createtemporary(cpat_iots,true);
        dbms_lob.createtemporary(cpat_java_objects,true);
        dbms_lob.createtemporary(cpat_ilm_policies,true);
        dbms_lob.createtemporary(cpat_incompatible_jobs,true);
        dbms_lob.createtemporary(cpat_restricted_packages,true);
        dbms_lob.createtemporary(cpat_dba_roles,true);
        dbms_lob.createtemporary(cpat_xmltypes,true);
        dbms_lob.createtemporary(cpat_xmlschema,true);
        dbms_lob.createtemporary(cpat_xmltype_tables,true);
        dbms_lob.createtemporary(cpat_xmldb_objects,true);
        dbms_lob.createtemporary(cpat_spatial_objs,true);
        dbms_lob.createtemporary(cpat_common_objs,true);
        dbms_lob.createtemporary(cpat_no_compression,true);
        dbms_lob.createtemporary(cpat_dblinks,true);
        dbms_lob.createtemporary(cpat_directories,true);
        dbms_lob.createtemporary(cpat_libraries,true);
        dbms_lob.createtemporary(cpat_trusted_server,true);
        dbms_lob.createtemporary(cpat_lcm_user,true);


        /* Removed in v5.0 for CPAT alignment

        -- Determine whether this database potentially has objects managed by Oracle
        SELECT COUNT(*) AS COUNT 
        INTO v_oracle_maintained 
        FROM DBA_TAB_COLS 
        WHERE TABLE_NAME='DBA_OBJECTS' 
        AND COLUMN_NAME='ORACLE_MAINTAINED' 
        AND OWNER='SYS';

        -- If it does, then the list of excluded schemas must be built dynamically

        l_excluded_schemas := SYS.ODCIVARCHAR2LIST();
        IF v_oracle_maintained > 0
        THEN -- Build list of schemas to exclude from analysis 
            FOR c_oracle_maintained_schema_row IN c_oracle_maintained_schema LOOP
                l_excluded_schemas.EXTEND(1);
                l_excluded_schemas(l_excluded_schemas.LAST) := c_oracle_maintained_schema_row.SCHEMA;
            END LOOP;

            -- Build comma delimited string version of excluded schemas to be used in dyanmic SQL
            v_excluded_schemas := '';
            FOR i IN 1 .. l_excluded_schemas.COUNT LOOP
                    v_excluded_schemas := v_excluded_schemas || '''' || l_excluded_schemas(i) || ''',';
            END LOOP;
        
            IF v_excluded_schemas IS NOT NULL THEN
                v_excluded_schemas := RTRIM(v_excluded_schemas, ',');
            END IF;
        ELSE -- If the database does not have schemas managed by Oracle, use the default list of excluded schemas
            l_excluded_schemas := SYS.ODCIVARCHAR2LIST(v_default_excluded_schemas);
            v_excluded_schemas := v_default_excluded_schemas;
        END If;
        */

        -- From v5.0, excluded schema list will be the default one to align with CPAT
        l_excluded_schemas := split_string_to_list(v_default_excluded_schemas);
        v_excluded_schemas := v_default_excluded_schemas;

        -- Build all dynamic query text so that it excludes the appropriate schemas from analysis
        l_xml_queryB :='SELECT OWNER AS DXT_OWNER, 
                                            TABLE_NAME AS DXT_TABLE_NAME, 
                                            STORAGE_TYPE AS DXT_STORAGE_TYPE 
                                        FROM DBA_XML_TABLES        
                                    WHERE STORAGE_TYPE != ''BINARY'' 
                                        AND OWNER NOT IN ('||v_excluded_schemas||')
                                    ORDER BY 1,2';

        l_xml_queryC :='SELECT OWNER AS DXS_OWNER, 
                                            SCHEMA_URL DXS_SCHEMA_URL
                                        FROM DBA_XML_SCHEMAS S   
                                    WHERE OWNER NOT IN ('||v_excluded_schemas||')
                                    ORDER BY 1,2';

        l_xml_queryD :='SELECT OWNER AS DXTC_OWNER, 
                                            TABLE_NAME DXTC_TABLE_NAME, 
                                            COLUMN_NAME DXTC_COLUMN_NAME, 
                                            STORAGE_TYPE DXTC_STORAGE_TYPE, 
                                            XMLSCHEMA DXTC_XMLSCHEMA, 
                                            SCHEMA_OWNER DXTC_SCHEMA_OWNER  
                                        FROM DBA_XML_TAB_COLS  
                                    WHERE (XMLSCHEMA IS NOT NULL OR STORAGE_TYPE != ''BINARY'') 
                                        AND OWNER NOT IN ('||v_excluded_schemas||')
                                    ORDER BY 1,2,3';

        c_spatial_sql := 'SELECT OWNER,
                                TABLE_NAME,
                                COLUMN_NAME,
                                DATA_TYPE
                            FROM DBA_TAB_COLUMNS
                        WHERE OWNER NOT IN ('||v_excluded_schemas||') 
                            AND DATA_TYPE IN '||Q'[('SDO_GEOMETRY','SDO_POINT','SDO_ELEM_INFO_ARRAY','SDO_ORDINATE_ARRAY','SDO_GEOMETRY_ARRAY','SDO_GEORASTER','SDO_PC','SDO_TIN','SDO_TOPO_GEOMETRY')  
                            AND DATA_TYPE_OWNER IN ('MDSYS','PUBLIC')]'|| 
                        ' ORDER BY 1,2,3';

        c_12c_libraries_sql :='SELECT OWNER, LIBRARY_NAME, FILE_SPEC, ORIGIN_CON_ID '||
                                    'FROM DBA_LIBRARIES 
                                    WHERE OWNER NOT IN ('||v_excluded_schemas||') 
                                    ORDER BY 1,2';

        c_11g_libraries_sql :='SELECT OWNER, LIBRARY_NAME, FILE_SPEC '||
                                    'FROM DBA_LIBRARIES 
                                    WHERE OWNER NOT IN ('||v_excluded_schemas||') 
                                    ORDER BY 1,2';

        -- Database Summary Record
        -- Open, Fetch and Close each of the cursors that form part of the database summary record
        OPEN c_database;
        FETCH c_database INTO c_database_row;
            v_dbid:=c_database_row.dbid;
            v_dbname:=c_database_row.name;
        CLOSE c_database;

        OPEN c_instance;
        FETCH c_instance INTO c_instance_row;
        CLOSE c_instance;

        -- If this database is a 12c database or higher, check to see if its a multitenant database (CDB)
        -- If it is, this is a pluugable database. Go and get the DBID for the pluggable. Otherwise we 
        -- use the DBID taken from the main database cursor against v$database.
        IF to_number(substr(c_instance_row.version,1,2))>=12
        THEN v_dynsql := c_multitenant_flag_sql;
            OPEN v_dyn_cursor FOR v_dynsql;
            FETCH v_dyn_cursor INTO c_multitenant_flag_value;
            CLOSE v_dyn_cursor;
            IF c_multitenant_flag_value = 'YES'
            THEN v_dynsql:=c_database_sql;
                OPEN v_dyn_cursor FOR v_dynsql;
                FETCH v_dyn_cursor INTO c_database_sql_dbid, c_database_sql_name;
                        v_dbid:=c_database_sql_dbid;
                        v_dbname:=c_database_sql_name;
                CLOSE v_dyn_cursor;
            END IF;
        END IF;


        OPEN c_registry;
        FETCH c_registry INTO c_registry_row;
        CLOSE c_registry;

        OPEN c_parameter;
        FETCH c_parameter INTO c_parameter_row;
        CLOSE c_parameter;

        OPEN c_db_size;
        FETCH c_db_size INTO c_db_size_row;
        CLOSE c_db_size;

        OPEN c_block_change_tracking;
        FETCH c_block_change_tracking INTO c_block_change_tracking_row;
        CLOSE c_block_change_tracking;

        OPEN c_encrypted_columns;
        FETCH c_encrypted_columns INTO c_encrypted_columns_row;
        CLOSE c_encrypted_columns;

        OPEN c_nls;
        FETCH c_nls INTO c_nls_row;
        CLOSE c_nls;

        OPEN c_national_char;
        FETCH c_national_char INTO c_national_char_row;
        CLOSE c_national_char;

        OPEN c_max_sessions;
        FETCH c_max_sessions INTO c_max_sessions_row;
        CLOSE c_max_sessions;

        OPEN c_avg_active;
        FETCH c_avg_active INTO c_avg_active_row;
        CLOSE c_avg_active;

        -- All Database PARAMETERS
        FOR c_all_parameters_row IN c_all_parameters LOOP

        new_clob_record:='MPACK_DB_PARAMETER'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_all_parameters%rowcount||'|'||
                        '{'||
                        '"'||'name'||'":"'||c_all_parameters_row.name||'",'||
                        '"'||'value'||'":"'||c_all_parameters_row.value||'",'||
                        '"'||'isdefault'||'":"'||c_all_parameters_row.isdefault||'",'||
                        '"'||'ismodified'||'":"'||c_all_parameters_row.ismodified||'",'||
                        '"'||'isdeprecated'||'":"'||c_all_parameters_row.isdeprecated||'",'||
                        '"'||'description'||'":"'||c_all_parameters_row.description||'"'||
                        '}'||
                        chr(10);
                        
        dbms_lob.writeappend(cpat_all_parameters, dbms_lob.getlength(new_clob_record), new_clob_record);                                             

        END LOOP;

        -- CPAT Detail Records
        -- Loop through each CPAT test cursor and append any matching exceptions to the respective CLOB
        -- set the rowcount variable to the cursor rowcount. This is added to the Database Summary Record.

        -- CPAT Check - Basic LOBS

        c_lobs_sql := 
        Q'[SELECT LOBS.OWNER, 
            LOBS.TABLE_NAME, 
            regexp_replace(LOBS.COLUMN_NAME,'"','') COLUMN_NAME /* To overcome issue with objects derived from Queues, Scheduler and nested records where " are used to demonstrate the object full identifier */
        FROM DBA_LOBS LOBS, DBA_TABLES TABS  
        WHERE ]'|| case 
                when to_number(substr(c_instance_row.version,1,2)) > 10 then Q'[LOBS.SECUREFILE = 'NO' AND ]'
                end 
                ||Q'[LOBS.OWNER NOT IN ('ANONYMOUS',
                                'APPQOSSYS',
                                'AUDSYS',
                                'CTXSYS',
                                'DBSFWUSER',
                                'DBSNMP',
                                'DIP',
                                'DVF',
                                'DVSYS',
                                'GGSYS',
                                'GSMADMIN_INTERNAL',
                                'GSMCATUSER',
                                'GSMROOTUSER',
                                'GSMUSER',
                                'LBACSYS',
                                'MDDATA',
                                'MDSYS',
                                'OJVMSYS',
                                'OLAPSYS',
                                'ORACLE_OCM',
                                'ORDDATA',
                                'ORDPLUGINS',
                                'ORDSYS',
                                'OUTLN',
                                'REMOTE_SCHEDULER_AGENT',
                                'SI_INFORMTN_SCHEMA',
                                'SYS',
                                'SYS$UMF',
                                'SYSBACKUP',
                                'SYSDG',
                                'SYSKM',
                                'SYSMAN',
                                'SYSRAC',
                                'SYSTEM',
                                'WMSYS',
                                'XDB',
                                'XS$NULL')
        AND TABS.OWNER=LOBS.OWNER 
        AND TABS.TABLE_NAME = LOBS.TABLE_NAME  
        AND NVL(TABS.TEMPORARY, 'N') <>'Y']';

        OPEN v_dyn_cursor FOR c_lobs_sql;
        LOOP
        FETCH v_dyn_cursor INTO c_lobs_owner, c_lobs_table_name, c_lobs_column_name;
        EXIT WHEN v_dyn_cursor%NOTFOUND;
        v_basic_lobs_rows := v_basic_lobs_rows +1;
        new_clob_record:='MPACK_BASIC_LOB'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        v_basic_lobs_rows||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_lobs_owner||'",'||
                        '"'||'table_name'||'":"'||c_lobs_table_name||'",'||
                        '"'||'column_name'||'":"'||c_lobs_column_name||'"'||
                        '}'||
                        chr(10);
                        
        dbms_lob.writeappend(cpat_basic_lobs, dbms_lob.getlength(new_clob_record), new_clob_record);                                             

        END LOOP;
        CLOSE  v_dyn_cursor;

        -- CPAT Check - Clustered Tables
        FOR c_cpat_clustered_tables_row IN c_cpat_clustered_tables LOOP

        new_clob_record:='MPACK_CLUSTERED_TABLE'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_clustered_tables%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_clustered_tables_row.owner||'",'||
                        '"'||'table_name'||'":"'||c_cpat_clustered_tables_row.table_name||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_clustered_tables, dbms_lob.getlength(new_clob_record), new_clob_record);                                             
        v_clustered_tables_rows:= c_cpat_clustered_tables%rowcount;

        END LOOP;

        -- CPAT Check - ROWID Columns
        FOR c_cpat_rowids_row IN c_cpat_rowids LOOP

        new_clob_record:='MPACK_ROWID_COLUMN'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_rowids%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_rowids_row.owner||'",'||
                        '"'||'table_name'||'":"'||c_cpat_rowids_row.table_name||'",'||
                        '"'||'column_name'||'":"'||c_cpat_rowids_row.column_name||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_rowid_columns, dbms_lob.getlength(new_clob_record), new_clob_record);                                             
        v_rowid_columns_rows:= c_cpat_rowids%rowcount;

        END LOOP;

        -- CPAT Check - Media Data Types
        FOR c_cpat_media_row IN c_cpat_media LOOP

        new_clob_record:='MPACK_MEDIA_COLUMN'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_media%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_media_row.owner||'",'||
                        '"'||'table_name'||'":"'||c_cpat_media_row.table_name||'",'||
                        '"'||'column_name'||'":"'||c_cpat_media_row.column_name||'",'||
                        '"'||'data_type'||'":"'||c_cpat_media_row.data_type||'"'||   
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_media_columns, dbms_lob.getlength(new_clob_record), new_clob_record);                             
        v_media_columns_rows:= c_cpat_media%rowcount;

        END LOOP;

        -- CPAT Check - External Tables
        FOR c_cpat_external_tabs_row IN c_cpat_external_tabs LOOP

        new_clob_record:='MPACK_EXTERNAL_TABLE'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_external_tabs%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_external_tabs_row.owner||'",'||
                        '"'||'table_name'||'":"'||c_cpat_external_tabs_row.table_name||'",'||
                        '"'||'type_owner'||'":"'||c_cpat_external_tabs_row.type_owner||'",'||
                        '"'||'type_name'||'":"'||c_cpat_external_tabs_row.type_name||'",'||
                        '"'||'default_directory_owner'||'":"'||c_cpat_external_tabs_row.default_directory_owner||'",'||
                        '"'||'default_directory_name'||'":"'||c_cpat_external_tabs_row.default_directory_name||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_external_tables, dbms_lob.getlength(new_clob_record), new_clob_record);             
        v_external_tables_rows:= c_cpat_external_tabs%rowcount;
        END LOOP;

        -- CPAT Check - Index Organized Tables
        FOR c_cpat_iots_row IN c_cpat_iots LOOP

        new_clob_record:='MPACK_IOT'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_iots%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_iots_row.owner||'",'||
                        '"'||'table_name'||'":"'||c_cpat_iots_row.table_name||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_iots, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_iots_rows:= c_cpat_iots%rowcount;

        END LOOP;

        -- CPAT Check - Java Objects
        FOR c_cpat_java_objects_row IN c_cpat_java_objects LOOP

        new_clob_record:='MPACK_JAVA_OBJECT'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_java_objects%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_java_objects_row.owner||'",'||
                        '"'||'object_name'||'":"'||c_cpat_java_objects_row.object_name||'",'||
                        '"'||'object_type'||'":"'||c_cpat_java_objects_row.object_type||'",'||
                        '"'||'status'||'":"'||c_cpat_java_objects_row.status||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_java_objects, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_java_objects_rows:= c_cpat_java_objects%rowcount;

        END LOOP;

        -- CPAT Check - Information Lifecycle Policies
        IF to_number(substr(c_instance_row.version,1,2))>=12
        THEN v_dynsql:=c_ilm_policies_sql;
            v_ilm_policies_rows:=0;
            OPEN v_dyn_cursor FOR v_dynsql;
            LOOP
                FETCH v_dyn_cursor INTO c_ilm_sql_object_owner, c_ilm_sql_policy_name, c_ilm_sql_object_name, c_ilm_sql_object_type;
                EXIT WHEN v_dyn_cursor%NOTFOUND;
                v_ilm_policies_rows:=v_ilm_policies_rows+1;
                new_clob_record:='MPACK_ILM_POLICY'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        v_ilm_policies_rows||'|'||
                        '{'||
                        '"'||'object_owner'||'":"'||c_ilm_sql_object_owner||'",'||
                        '"'||'policy_name'||'":"'||c_ilm_sql_policy_name||'",'||
                        '"'||'object_name'||'":"'||c_ilm_sql_object_name||'",'||
                        '"'||'object_type'||'":"'||c_ilm_sql_object_type||'"'||
                        '}'||
                        chr(10);
                        dbms_lob.writeappend(cpat_ilm_policies, dbms_lob.getlength(new_clob_record), new_clob_record);
            END LOOP;
            CLOSE v_dyn_cursor;
        END IF;                

        -- CPAT Check - Incompatible Scheduled Jobs and Programs
        FOR c_cpat_incompatible_jobs_row IN c_cpat_incompatible_jobs LOOP

        new_clob_record:='MPACK_INCOMPATIBLE_JOB'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_incompatible_jobs%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_incompatible_jobs_row.owner||'",'||
                        '"'||'name'||'":"'||c_cpat_incompatible_jobs_row.name||'",'||
                        '"'||'type'||'":"'||c_cpat_incompatible_jobs_row.type||'",'||
                        '"'||'locus'||'":"'||c_cpat_incompatible_jobs_row.locus||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_incompatible_jobs, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_incompatible_jobs_rows:= c_cpat_incompatible_jobs%rowcount;

        END LOOP;

        -- CPAT Check - References to Oracle Restricted Packages
        FOR c_cpat_restricted_packages_row IN c_cpat_restricted_packages LOOP

        new_clob_record:='MPACK_RESTRICTED_PACKAGE'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_restricted_packages%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_restricted_packages_row.owner||'",'||
                        '"'||'name'||'":"'||c_cpat_restricted_packages_row.name||'",'||
                        '"'||'type'||'":"'||c_cpat_restricted_packages_row.type||'",'||
                        '"'||'referenced_name'||'":"'||c_cpat_restricted_packages_row.referenced_name||'",'||
                        '"'||'support'||'":"'||c_cpat_restricted_packages_row.support||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_restricted_packages, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_restricted_packages_rows:= c_cpat_restricted_packages%rowcount;

        END LOOP;

        -- CPAT Check - Users That Have Been Granted DBA Privileges
        FOR c_cpat_dba_roles_row IN c_cpat_dba_roles LOOP

        new_clob_record:='MPACK_DBA_ROLE'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_dba_roles%rowcount||'|'||
                        '{'||
                        '"'||'grantee'||'":"'||c_cpat_dba_roles_row.grantee||'",'||
                        '"'||'granted_role'||'":"'||c_cpat_dba_roles_row.granted_role||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_dba_roles, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_dba_roles_rows:= c_cpat_dba_roles%rowcount;

        END LOOP;

        -- CPAT Check - Identify use of XMLTYPEs
        --
        BEGIN
        EXECUTE IMMEDIATE l_xml_queryD BULK COLLECT INTO l_xml_queryD_collection;
        FOR idqD IN 1..l_xml_queryD_collection.COUNT
            LOOP
                new_clob_record:='MPACK_XMLTYPE'||'|GUIDPLACEHOLDER|'||
                                v_dbid||'|'||
                                v_extract_date_time||'|'||
                                idqD||'|'||
                                '{'||
                                '"'||'owner'||'":"'||l_xml_queryD_collection(idqD).dxtc_owner||'",'||
                                '"'||'table_name'||'":"'||l_xml_queryD_collection(idqD).dxtc_table_name||'",'||
                                '"'||'column_name'||'":"'||l_xml_queryD_collection(idqD).dxtc_column_name||'",'||
                                '"'||'storage_type'||'":"'||l_xml_queryD_collection(idqD).dxtc_storage_type||'",'||
                                '"'||'xmlschema'||'":"'||l_xml_queryD_collection(idqD).dxtc_xmlschema||'",'||
                                '"'||'schema_owner'||'":"'||l_xml_queryD_collection(idqD).dxtc_schema_owner||'"'||
                                '}'||
                                chr(10);

                dbms_lob.writeappend(cpat_xmltypes, dbms_lob.getlength(new_clob_record), new_clob_record);
                v_xmltypes_rows:= l_xml_queryD_collection.count;
            END LOOP;
        EXCEPTION
        WHEN OTHERS THEN 
        l_xml_check2:='N';
        null;
        END;

        -- CPAT Check - Identify use of XMLSCHEMAs
        --
        -- 11g check as tables may not exist
        -- 11g optional tables
        BEGIN
        EXECUTE IMMEDIATE l_xml_queryC BULK COLLECT INTO l_xml_queryC_collection;
        FOR idqC IN 1..l_xml_queryC_collection.COUNT
            LOOP
                new_clob_record:='MPACK_XMLSCHEMA'||'|GUIDPLACEHOLDER|'||
                                v_dbid||'|'||
                                v_extract_date_time||'|'||
                                idqC||'|'||
                                '{'||
                                '"'||'owner'||'":"'||l_xml_queryC_collection(idqC).dxs_owner||'",'||
                                '"'||'schema_url'||'":"'||l_xml_queryC_collection(idqC).dxs_schema_url||'"'||
                                '}'||
                                chr(10);

        dbms_lob.writeappend(cpat_xmlschema, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_xmlschema_rows:= l_xmlschema_count;

            END LOOP;
        EXCEPTION
        WHEN OTHERS THEN 
        l_xml_check3:='N';
        null;
        END;

        -- CPAT Check - Identify Presence of XMLTYPE Tables
        BEGIN
        EXECUTE IMMEDIATE l_xml_queryB BULK COLLECT INTO l_xml_queryB_collection;
        FOR idqB IN 1..l_xml_queryB_collection.COUNT
            LOOP
                new_clob_record:='MPACK_XMLTYPE_TABLE'||'|GUIDPLACEHOLDER|'||
                                v_dbid||'|'||
                                v_extract_date_time||'|'||
                                idqB||'|'||
                                '{'||
                                '"'||'owner'||'":"'||l_xml_queryB_collection(idqB).dxt_owner||'",'||
                                '"'||'table_name'||'":"'||l_xml_queryB_collection(idqB).dxt_table_name||'",'||
                                '"'||'storage_type'||'":"'||l_xml_queryB_collection(idqB).dxt_storage_type||'"'||
                                '}'||
                                chr(10);
                dbms_lob.writeappend(cpat_xmltype_tables, dbms_lob.getlength(new_clob_record), new_clob_record);
                v_xmltype_tables_rows:= l_xml_queryB_collection.count;
            END LOOP;
        EXCEPTION
        WHEN OTHERS THEN 
        l_xml_check4:='N';
        null;
        END;

        -- CPAT Check - Check for XMLDB Objects
        -- TEST EXECUTE STATEMENT if Successfull run loop
        -- if not then do not run loop
        BEGIN
        EXECUTE IMMEDIATE l_xml_queryA BULK COLLECT INTO l_xml_queryA_collection;
        FOR idqA IN 1..l_xml_queryA_collection.COUNT
            LOOP
                new_clob_record:='MPACK_XMLDB_OBJECTS'||'|GUIDPLACEHOLDER|'||
                                v_dbid||'|'||
                                v_extract_date_time||'|'||
                                '1'||'|'||
                                '{'||
                                '"'||'count'||'":"'||l_xml_queryA_collection(idqA).counter||'"'|| 
                                '}'||
                                chr(10);
                dbms_lob.writeappend(cpat_xmldb_objects, dbms_lob.getlength(new_clob_record), new_clob_record);
                v_xmldb_objects_rows := 1;
            END LOOP;
        EXCEPTION
        WHEN OTHERS THEN 
        l_xml_check:='N';
        null;
        END;


        -- CPAT Check - Identify Presence of Spatial objects if Spatial option is installed
        IF c_registry_row.spatial_status != '*NOTPRESENT*'
        THEN v_dynsql:=c_spatial_sql;
            -- dbms_output.put_line(c_spatial_sql);
            v_spatial_obj_rows:=0;
            dbms_output.put_line('Spatial option found');
            OPEN v_dyn_cursor FOR v_dynsql;
            LOOP
                FETCH v_dyn_cursor INTO c_spatial_sql_owner, c_spatial_sql_table_name, c_spatial_sql_column_name, c_spatial_sql_data_type;

                EXIT WHEN v_dyn_cursor%NOTFOUND;
                v_spatial_obj_rows:=v_spatial_obj_rows+1;

                dbms_output.put_line('Spatial object found');

                new_clob_record:='MPACK_SPATIAL_OBJ'||'|GUIDPLACEHOLDER|'||
                                v_dbid||'|'||
                                v_extract_date_time||'|'||
                                v_spatial_obj_rows||'|'||
                                '{'||
                                '"'||'owner'||'":"'||c_spatial_sql_owner||'",'||
                                '"'||'table_name'||'":"'||c_spatial_sql_table_name||'",'||                 
                                '"'||'column_name'||'":"'||c_spatial_sql_column_name||'",'||
                                '"'||'data_type'||'":"'||c_spatial_sql_data_type||'"'||
                                '}'||
                                chr(10);
                dbms_lob.writeappend(cpat_spatial_objs, dbms_lob.getlength(new_clob_record), new_clob_record);
            END LOOP;
            CLOSE v_dyn_cursor;
        ELSE v_spatial_obj_rows:=0;
        END IF;

        -- CPAT Check - Dynamic SQL to identify resence of Common objects in 12.2 and later databases
        IF to_number(substr(c_instance_row.version,1,4))>=12.2
        THEN v_dynsql:=c_common_sql;
            v_common_obj_rows:=0;
            OPEN v_dyn_cursor FOR v_dynsql;
            LOOP
                FETCH v_dyn_cursor INTO c_common_sql_object_name, c_common_sql_object_type; -- Removed in v5.0, c_common_sql_owner, c_common_sql_sharing, c_common_sql_application;

                EXIT WHEN v_dyn_cursor%NOTFOUND;
                v_common_obj_rows:=v_common_obj_rows+1;
                
                new_clob_record:='MPACK_COMMON_OBJECTS'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        v_common_obj_rows||'|'||
                        '{'||
                        -- Removed in v5.0 '"'||'owner'||'":"'||c_common_sql_owner||'",'||
                        '"'||'owner'||'":"'||c_common_sql_object_type||'",'||
                        '"'||'object_name'||'":"'||c_common_sql_object_name||'"'||
                        -- Removed in v5.0 '"'||'sharing'||'":"'||c_common_sql_sharing||'",'||
                        -- Removed in v5.0 '"'||'application'||'":"'||c_common_sql_application||'"'||
                        '}'||
                        chr(10);
                        dbms_lob.writeappend(cpat_common_objs, dbms_lob.getlength(new_clob_record), new_clob_record);            
            END LOOP;
            CLOSE v_dyn_cursor;
        END IF;      
        
        -- CPAT Check - Identify tables with COMPRESSION disabled
        FOR c_cpat_no_compression_row IN c_cpat_no_compression LOOP

        new_clob_record:='MPACK_COMPRESSION_DISABLED'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_no_compression%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_no_compression_row.owner||'",'|| 
                        '"'||'count'||'":"'||c_cpat_no_compression_row.NO_COMPRESSION_TABLES||'"'||
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_no_compression, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_no_compression_rows:= c_cpat_no_compression%rowcount;

        END LOOP;

        -- CPAT Check - Check for database links
        FOR c_cpat_dblinks_row IN c_cpat_dblinks LOOP

        new_clob_record:='MPACK_DBLINK'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_dblinks%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_dblinks_row.owner||'",'||
                        '"'||'dblink'||'":"'||c_cpat_dblinks_row.db_link||'",'|| 
                        '"'||'host'||'":"'||c_cpat_dblinks_row.host||'"'||                    
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_dblinks, length(new_clob_record), new_clob_record);
        v_dblinks_rows:= c_cpat_dblinks%rowcount;

        END LOOP;

        -- CPAT Check - Check for directories
        FOR c_cpat_directories_row IN c_cpat_directories LOOP

        new_clob_record:='MPACK_DIRECTORY'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_directories%rowcount||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_cpat_directories_row.owner||'",'||
                        '"'||'directory_name'||'":"'||c_cpat_directories_row.directory_name||'",'|| 
                        '"'||'directory_path'||'":"'||c_cpat_directories_row.directory_path||'"'||                    
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_directories, length(new_clob_record), new_clob_record);
        v_directories_rows := c_cpat_directories%rowcount;

        END LOOP;

        -- CPAT Check - Dynamic SQL to identify resence of libraries
        IF to_number(substr(c_instance_row.version,1,2))>=12
        THEN v_dynsql:=c_12c_libraries_sql;
            v_libraries_rows:=0;
            OPEN v_dyn_cursor FOR v_dynsql;
            LOOP
                FETCH v_dyn_cursor INTO c_libraries_owner, c_libraries_library_name, c_libraries_file_spec, c_libraries_12c_conid;
                EXIT WHEN v_dyn_cursor%NOTFOUND;
                v_libraries_rows:=v_libraries_rows+1;
                new_clob_record:='MPACK_LIBRARY'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        v_libraries_rows||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_libraries_owner||'",'||
                        '"'||'library_name'||'":"'||c_libraries_library_name||'",'||
                        '"'||'file_spec'||'":"'||c_libraries_file_spec||'",'||
                        '"'||'container_id'||'":"'||c_libraries_12c_conid||'"'||
                        '}'||
                        chr(10);
                        dbms_lob.writeappend(cpat_libraries, dbms_lob.getlength(new_clob_record), new_clob_record);     
            END LOOP;
            CLOSE v_dyn_cursor;
        ELSE v_dynsql:=c_11g_libraries_sql;
            v_libraries_rows:=0;
            OPEN v_dyn_cursor FOR v_dynsql;
            LOOP
                FETCH v_dyn_cursor INTO c_libraries_owner, c_libraries_library_name, c_libraries_file_spec;
                EXIT WHEN v_dyn_cursor%NOTFOUND;
                v_libraries_rows:=v_libraries_rows+1;
                new_clob_record:='MPACK_LIBRARY'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        v_libraries_rows||'|'||
                        '{'||
                        '"'||'owner'||'":"'||c_libraries_owner||'",'||
                        '"'||'library_name'||'":"'||c_libraries_library_name||'",'||
                        '"'||'file_spec'||'":"'||c_libraries_file_spec||'"'||
                        '}'||
                        chr(10);
                        dbms_lob.writeappend(cpat_libraries, dbms_lob.getlength(new_clob_record), new_clob_record);     
            END LOOP;
            CLOSE v_dyn_cursor;
        END IF;  

        -- CPAT Check - Check for trusted servers
        FOR c_cpat_trusted_server_row IN c_cpat_trusted_server LOOP

        new_clob_record:='MPACK_TRUSTED_SERVER'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_trusted_server%rowcount||'|'||
                        '{'||
                        '"'||'trust'||'":"'||c_cpat_trusted_server_row.trust||'",'||
                        '"'||'name'||'":"'||c_cpat_trusted_server_row.name||'"'||                    
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_trusted_server, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_trusted_server_rows := c_cpat_trusted_server%rowcount;

        END LOOP;

        -- CPAT Check - Check for LCM Super User
        FOR c_cpat_lcm_user_row IN c_cpat_lcm_user LOOP

        new_clob_record:='MPACK_LCM_SUPER_USER'||'|GUIDPLACEHOLDER|'||
                        v_dbid||'|'||
                        v_extract_date_time||'|'||
                        c_cpat_lcm_user%rowcount||'|'||
                        '{'||
                        '"'||'status'||'":"'||c_cpat_lcm_user_row.status||'"'||                 
                        '}'||
                        chr(10);

        dbms_lob.writeappend(cpat_lcm_user, dbms_lob.getlength(new_clob_record), new_clob_record);
        v_lcm_user_rows := c_cpat_lcm_user%rowcount;

        END LOOP;



        -- Build the Database Summary Record

        new_clob_record:=to_char(  
        'MPACK_DATABASE'||'|GUIDPLACEHOLDER|'||
        v_dbid||'|'||
        v_extract_date_time||'|'||    
        '0|'||
        '{'||
        '"'||'db_name'||'":"'||v_dbname||'",'||
        '"'||'db_log_mode'||'":"'||c_database_row.log_mode||'",'||
        '"'||'db_controlfile_type'||'":"'||c_database_row.controlfile_type||'",'||
        '"'||'db_open_mode'||'":"'||c_database_row.open_mode||'",'||
        '"'||'db_protection_level'||'":"'||c_database_row.protection_level||'",'||
        '"'||'db_database_role'||'":"'||c_database_row.database_role||'",'||
        '"'||'db_dataguard_broker'||'":"'||c_database_row.dataguard_broker||'",'||
        '"'||'db_supplemental_logging'||'":"'||c_database_row.supplemental_logging||'",'||
        '"'||'db_force_logging'||'":"'||c_database_row.force_logging||'",'||
        '"'||'db_platform_name'||'":"'||c_database_row.platform_name||'",'||
        '"'||'db_flashback_on'||'":"'||c_database_row.flashback_on||'",'||
        '"'||'instance_number'||'":"'||c_instance_row.instance_number||'",'||
        '"'||'instance_name'||'":"'||c_instance_row.instance_name||'",'||
        '"'||'db_host_name'||'":"'||c_instance_row.host_name||'",'||
        '"'||'db_version'||'":"'||c_instance_row.version||'",'||
        '"'||'opt_warehouse_builder_status'||'":"'||c_registry_row.warehouse_builder_status||'",'||
        '"'||'opt_olap_status'||'":"'||c_registry_row.olap_status||'",'||
        '"'||'opt_spatial_status'||'":"'||c_registry_row.spatial_status||'",'||
        '"'||'opt_multimedia_status'||'":"'||c_registry_row.multimedia_status||'",'||
        '"'||'opt_xmldb_status'||'":"'||c_registry_row.xmldb_status||'",'||
        '"'||'opt_text_status'||'":"'||c_registry_row.text_status||'",'||
        '"'||'opt_expression_filter_status'||'":"'||c_registry_row.expression_filter_status||'",'||
        '"'||'opt_rules_manager_status'||'":"'||c_registry_row.rules_manager_status||'",'||
        '"'||'opt_workspace_manager_status'||'":"'||c_registry_row.workspace_manager_status||'",'||
        '"'||'opt_catalog_status'||'":"'||c_registry_row.catalog_status||'",'||
        '"'||'opt_catproc_status'||'":"'||c_registry_row.catproc_status||'",'||
        '"'||'opt_javavm_status'||'":"'||c_registry_row.javavm_status||'",'||
        '"'||'opt_xdk_status'||'":"'||c_registry_row.xml_developer_kit_status||'",'||
        '"'||'opt_java_catalog_status'||'":"'||c_registry_row.java_catalog_status||'",'||
        '"'||'opt_analytics_ws_status'||'":"'||c_registry_row.analytics_ws_status||'",'||
        '"'||'opt_olap_api_status'||'":"'||c_registry_row.olap_api_status||'",'||
        '"'||'opt_rac_status'||'":"'||c_registry_row.rac_status||'",'||
        '"'||'opt_label_security_status'||'":"'||c_registry_row.label_security_status||'",'||
        '"'||'opt_data_vault_status'||'":"'||c_registry_row.data_vault_status||'",'||
        '"'||'param_cpu_count'||'":"'||c_parameter_row.cpu||'",'||
        '"'||'param_cpu_count_modified'||'":"'||c_parameter_row.cpu_modified||'",'||
        '"'||'param_sga_size'||'":"'||c_parameter_row.sga||'",'||
        '"'||'param_sga_size_modified'||'":"'||c_parameter_row.sga_modified||'",'||
        '"'||'param_sga_max'||'":"'||c_parameter_row.sga_max||'",'||
        '"'||'param_sga_max_modified'||'":"'||c_parameter_row.sga_max_modified||'",'||
        '"'||'param_memory_size'||'":"'||c_parameter_row.memory||'",'||
        '"'||'param_memory_size_modified'||'":"'||c_parameter_row.memory_modified||'",'||
        '"'||'param_memory_max'||'":"'||c_parameter_row.memory_max||'",'||
        '"'||'param_memory_max_modified'||'":"'||c_parameter_row.memory_max_modified||'",'||
        '"'||'param_pga_size'||'":"'||c_parameter_row.pga||'",'||
        '"'||'param_pga_size_modified'||'":"'||c_parameter_row.pga_modified||'",'||
        '"'||'param_pga_max'||'":"'||c_parameter_row.pga_max||'",'||
        '"'||'param_pga_max_modified'||'":"'||c_parameter_row.pga_max_modified||'",'||
        '"'||'param_shared_pool_size'||'":"'||c_parameter_row.shared_pool||'",'||
        '"'||'param_shared_pool_size_modified'||'":"'||c_parameter_row.shared_pool_modified||'",'||
        '"'||'param_db_cache_size'||'":"'||c_parameter_row.cache_size||'",'||
        '"'||'param_db_cache_size_modified'||'":"'||c_parameter_row.cache_size_modified||'",'||
        '"'||'param_db_block_buffers'||'":"'||c_parameter_row.block_buffers||'",'||
        '"'||'param_db_block_buffers_modified'||'":"'||c_parameter_row.block_buffers_modified||'",'||
        '"'||'param_db_keep_cache'||'":"'||c_parameter_row.keep_cache||'",'||
        '"'||'param_db_keep_cache_modified'||'":"'||c_parameter_row.keep_cache_modified||'",'||
        '"'||'param_db_recycle_cache'||'":"'||c_parameter_row.recycle_cache||'",'||
        '"'||'param_db_recycle_cache_modified'||'":"'||c_parameter_row.recycle_cache_modified||'",'||
        '"'||'param_streams_pool_size'||'":"'||c_parameter_row.streams_pool||'",'||
        '"'||'param_streams_pool_size_modified'||'":"'||c_parameter_row.streams_pool_modified||'",'||
        '"'||'param_log_buffer'||'":"'||c_parameter_row.log_buffer||'",'||
        '"'||'param_log_buffer_modified'||'":"'||c_parameter_row.log_buffer_modified||'",'||
        '"'||'param_inmemory_size'||'":"'||c_parameter_row.inmemory||'",'||
        '"'||'param_inmemory_size_modified'||'":"'||c_parameter_row.inmemory_modified||'",'||
        '"'||'param_dispatchers'||'":"'||c_parameter_row.dispatchers||'",'||
        '"'||'param_dispatchers_modified'||'":"'||c_parameter_row.dispatchers_modified||'",'||
        '"'||'param_max_dispatchers'||'":"'||c_parameter_row.dispatchers#||'",'||
        '"'||'param_max_dispatchers_modified'||'":"'||c_parameter_row.dispatchers#_modified||'",'||
        '"'||'param_shared_servers'||'":"'||c_parameter_row.shared_servers||'",'||
        '"'||'param_shared_servers_modified'||'":"'||c_parameter_row.shared_servers_modified||'",'||
        '"'||'param_parallel_degree_policy'||'":"'||c_parameter_row.parallel_policy||'",'||
        '"'||'param_parallel_degree_policy_modified'||'":"'||c_parameter_row.parallel_policy_modified||'",'||
        '"'||'param_parallel_degree_level'||'":"'||c_parameter_row.parallel_degree||'",'||
        '"'||'param_parallel_degree_level_modified'||'":"'||c_parameter_row.parallel_degree_modified||'",'||
        '"'||'param_parallel_max_servers'||'":"'||c_parameter_row.parallel_servers#||'",'||
        '"'||'param_parallel_max_servers_modified'||'":"'||c_parameter_row.parallel_servers#_modified||'",'||
        '"'||'param_parallel_server_target'||'":"'||c_parameter_row.parallel_svr_tgt||'",'||
        '"'||'param_parallel_server_target_modified'||'":"'||c_parameter_row.parallel_svr_tgt_modified||'",'||
        '"'||'param_parallel_threads_per_cpu'||'":"'||c_parameter_row.parallel_cpu||'",'||
        '"'||'param_parallel_threads_per_cpu_modified'||'":"'||c_parameter_row.parallel_cpu_modified||'",'||
        '"'||'size_total_used_gb'||'":"'||c_db_size_row.total_used_db_size_gb||'",'||
        '"'||'size_current_used_gb'||'":"'||c_db_size_row.total_current_db_size_gb||'",'||
        '"'||'size_max_allocated_gb'||'":"'||c_db_size_row.total_max_allocated_db_size_gb||'",'||
        '"'||'db_block_change_tracking'||'":"'||c_block_change_tracking_row.status||'",'||
        '"'||'db_encrypted_column_count'||'":"'||c_encrypted_columns_row.total_cols||'",'||
        '"'||'nls_characterset'||'":"'||c_nls_row.value||'",'||
        '"'||'nls_national_characterset'||'":"'||c_national_char_row.value||'",'||
        '"'||'size_max_sessions_ever'||'":"'||c_max_sessions_row.highwater||'",'||
        '"'||'size_avg_active_sessions'||'":"'||c_avg_active_row.highwater||'",'||
        '"'||'core_basic_lobs_count'||'":"'||v_basic_lobs_rows||'",'||
        '"'||'core_clustered_tables_count'||'":"'||v_clustered_tables_rows||'",'||
        '"'||'core_rowid_columns_count'||'":"'||v_rowid_columns_rows||'",'||
        '"'||'core_media_columns_count'||'":"'||v_media_columns_rows||'",'||
        '"'||'core_external_tables_count'||'":"'||v_external_tables_rows||'",'||
        '"'||'core_iots_count'||'":"'||v_iots_rows||'",'||
        '"'||'core_java_objects_count'||'":"'||v_java_objects_rows||'",'||
        '"'||'core_ilm_policies_count'||'":"'||v_ilm_policies_rows||'",'||
        '"'||'core_incompatible_jobs_count'||'":"'||v_incompatible_jobs_rows||'",'||
        '"'||'core_restricted_packages_count'||'":"'||v_restricted_packages_rows||'",'||
        '"'||'core_dba_roles_count'||'":"'||v_dba_roles_rows||'",'||
        '"'||'core_xmltypes_count'||'":"'||v_xmltypes_rows||'",'||
        '"'||'core_xmlschema_count'||'":"'|| v_xmlschema_rows||'",'||
        '"'||'core_xmltype_tables_count'||'":"'||v_xmltype_tables_rows||'",'||
        '"'||'core_xmldb_objects_count'||'":"'||v_xmldb_objects_rows||'",'||
        '"'||'core_spatial_objs_count'||'":"'||v_spatial_obj_rows||'",'||
        '"'||'core_common_objs_count'||'":"'||v_common_obj_rows||'",'||
        '"'||'core_compression_disabled_count'||'":"'||v_no_compression_rows||'",'||
        '"'||'core_dblinks_count'||'":"'||v_dblinks_rows ||'",'||
        '"'||'core_directories_count'||'":"'||v_directories_rows ||'",'||
        '"'||'core_libraries_count'||'":"'||v_libraries_rows||'",'||
        '"'||'core_trusted_server_count'||'":"'||v_trusted_server_rows||'",'||
        '"'||'core_lcm_user_count'||'":"'||v_lcm_user_rows||'"'||
        '}'||
        chr(10));

        dbms_lob.writeappend(mpack_summary, dbms_lob.getlength(new_clob_record), new_clob_record);  

        -- Pass the contents of each CLOB to the corresponding SQLPLUS BIND variable
        select trim(mpack_summary) into :mpack_database from dual;
        select trim(cpat_basic_lobs) into :mpack_basic_lobs from dual;
        select trim(cpat_clustered_tables) into :mpack_clustered_tables from dual;
        select trim(cpat_rowid_columns) into :mpack_rowid_columns from dual;
        select trim(cpat_media_columns) into :mpack_media_columns from dual;
        select trim(cpat_external_tables) into :mpack_external_tables from dual;
        select trim(cpat_iots) into :mpack_iots from dual;
        select trim(cpat_java_objects) into :mpack_java_objects from dual;
        select trim(cpat_ilm_policies) into :mpack_ilm_policies from dual;
        select trim(cpat_incompatible_jobs) into :mpack_incompatible_jobs from dual;
        select trim(cpat_restricted_packages) into :mpack_restricted_packages from dual;
        select trim(cpat_dba_roles) into :mpack_dba_roles from dual;
        select trim(cpat_xmltypes) into :mpack_xmltypes from dual;
        select trim(cpat_xmlschema) into :mpack_xmlschema from dual;
        select trim(cpat_xmltype_tables) into :mpack_xmltype_tables from dual;
        select trim(cpat_xmldb_objects) into :mpack_xmldb_objects from dual;
        select trim(cpat_spatial_objs) into :mpack_spatial_objs from dual;
        select trim(cpat_common_objs) into :mpack_common_objs from dual;
        select trim(cpat_no_compression) into :mpack_no_compression from dual;
        select trim(cpat_dblinks) into :mpack_dblinks from dual;
        select trim(cpat_directories) into :mpack_directories from dual;
        select trim(cpat_libraries) into :mpack_libraries from dual;
        select trim(cpat_trusted_server) into :mpack_trusted_server from dual;
        select trim(cpat_lcm_user) into :mpack_lcm_user from dual;
        select trim(cpat_all_parameters) into :mpack_all_parameters from dual;

        -- Clean up the temporary clobs
        dbms_lob.freetemporary(cpat_basic_lobs);
        dbms_lob.freetemporary(cpat_clustered_tables);
        dbms_lob.freetemporary(cpat_rowid_columns);
        dbms_lob.freetemporary(cpat_media_columns);
        dbms_lob.freetemporary(cpat_external_tables);
        dbms_lob.freetemporary(cpat_iots);
        dbms_lob.freetemporary(cpat_java_objects);
        dbms_lob.freetemporary(cpat_ilm_policies);
        dbms_lob.freetemporary(cpat_incompatible_jobs);
        dbms_lob.freetemporary(cpat_restricted_packages);
        dbms_lob.freetemporary(cpat_dba_roles);
        dbms_lob.freetemporary(cpat_xmltypes);
        dbms_lob.freetemporary(cpat_xmlschema);
        dbms_lob.freetemporary(cpat_xmltype_tables);
        dbms_lob.freetemporary(cpat_xmldb_objects);
        dbms_lob.freetemporary(cpat_spatial_objs);
        dbms_lob.freetemporary(cpat_common_objs);
        dbms_lob.freetemporary(cpat_no_compression);
        dbms_lob.freetemporary(cpat_dblinks);
        dbms_lob.freetemporary(cpat_directories);
        dbms_lob.freetemporary(cpat_libraries);
        dbms_lob.freetemporary(cpat_trusted_server);
        dbms_lob.freetemporary(cpat_lcm_user);
        dbms_lob.freetemporary(cpat_all_parameters);

        END;
        /

REM Print the CLOB contents for each section
        print mpack_database
        print mpack_basic_lobs
        print mpack_clustered_tables
        print mpack_rowid_columns
        print mpack_media_columns
        print mpack_external_tables
        print mpack_iots
        print mpack_java_objects
        print mpack_ilm_policies
        print mpack_incompatible_jobs
        print mpack_restricted_packages
        print mpack_dba_roles
        print mpack_xmltypes
        print mpack_xmlschema
        print mpack_xmltype_tables
        print mpack_xmldb_objects
        print mpack_spatial_objs
        print mpack_common_objs
REM print mpack_no_compression
        print mpack_dblinks
        print mpack_directories
        print mpack_libraries
        print mpack_trusted_server
        print mpack_lcm_user
        print mpack_all_parameters

        exit



