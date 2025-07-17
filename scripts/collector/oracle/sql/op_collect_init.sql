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
/*
This script access Automatic Repository Workload (AWR) views in the database dictionary.
Please ensure you have proper licensing. For more information consult Oracle Support Doc ID 1490798.1

*/
--prompt Param1 = &1

--define version = '&1'
define colspr = '|'

exec dbms_application_info.set_action('DB MIGRATION ASSESSMENT');

-- Set the environment to a known state, overriding any custom configuration.
@@op_set_sql_env.sql
set headsep off
set trimspool on
set lines 32000
set pagesize 0 embedded on
set feed off
set underline off
set verify off
set head off
set scan on
set pause off
set wrap on
set echo off
set appinfo 'DB MIGRATION ASSESSMENT'
set colsep '|'
set timing off
set time off


alter session set nls_numeric_characters='.,';
alter session set nls_date_format='YYYY-MM-DD HH24:MI:SS';

set termout on
whenever sqlerror exit failure
whenever oserror continue

variable v_pkey VARCHAR2(100);
variable v_statsWindow NUMBER;  
BEGIN
SELECT '&p_statsWindow' INTO :v_statsWindow FROM DUAL;
END;
/

variable v_dmaVersion VARCHAR2(30);
BEGIN
SELECT '&dmaVersion' INTO :v_dmaVersion FROM DUAL;
END;
/

variable v_statssrc VARCHAR2(20);
BEGIN
  :v_statssrc := '&s_statssrc';
END;
/


-- To handle collection from within a Dataguard standby
variable v_umfflag VARCHAR2(100);

-- To handle column 'LOGGING' in 'DBA_PDBS'.  Depends on Oracle version
variable v_pdb_logging_flag VARCHAR2(1);

-- To handle column 'DEFAULT_VALUE' in 'V_$SYSTEM_PARAMETER'
variable v_dflt_value_flag  VARCHAR2(1);

-- to handle column 'COMPRESS_FOR' in 'DBA_TABLES'. Depends on Oracle version
variable v_compress_col VARCHAR2(20);
prompt Creating variables - begin
variable v_lob_compression_col         VARCHAR2(30);
variable v_lob_part_compression_col    VARCHAR2(30);
variable v_lob_subpart_compression_col VARCHAR2(30);
variable v_lob_dedup_col               VARCHAR2(30);
variable v_lob_part_dedup_col          VARCHAR2(30);
variable v_lob_subpart_dedup_col       VARCHAR2(30);

variable v_index_visibility            VARCHAR2(30);

variable v_io_function_sql             VARCHAR2(20);

variable v_dma_source_id               VARCHAR2(100);
variable v_manual_unique_id            VARCHAR2(100);
variable v_min_snapid                  NUMBER;
variable v_max_snapid                  NUMBER;
variable v_min_snaptime                VARCHAR2(20);
variable v_max_snaptime                VARCHAR2(20);

variable v_dbid                        NUMBER;
variable v_dbversion                   VARCHAR2(20);
variable v_dbname                      VARCHAR2(100);
variable v_hora                        VARCHAR2(20);
variable v_host                        VARCHAR2(100);
variable v_instance                    VARCHAR2(100);
variable v_app_join_pdbsinfo_cond      VARCHAR2(100);
variable v_app_join_dbsum_cond         VARCHAR2(100);

prompt Creating variables - end

-- Session settings to support creating substitution variables for the scripts.
column instnc                        new_value s_inst noprint
column hostnc                        new_value s_host noprint
column horanc                        new_value s_hora noprint
column dbname                        new_value s_dbname noprint
column dbversion                     new_value s_dbversion noprint
column min_snapid                    new_value s_min_snapid noprint
column min_snaptime                  new_value s_min_snaptime noprint
column max_snapid                    new_value s_max_snapid noprint
column max_snaptime                  new_value s_max_snaptime noprint
column umf_test                      new_value s_umf_test noprint
--column p_dma_source_id               new_value s_dma_source_id noprint
column p_dbid                        new_value s_dbid noprint
column p_tblprefix                   new_value s_tblprefix noprint
column p_is_container                new_value s_is_container noprint
column p_cdb_join_cond               new_value s_cdb_join_cond noprint
column p_pdb_join_cond               new_value s_pdb_join_cond noprint
column p_dbparam_dflt_col            new_value s_dbparam_dflt_col noprint
column p_editionable_col             new_value s_editionable_col noprint
column p_tenancy                     new_value s_tenancy noprint
column p_db_container_col            new_value s_db_container_col noprint
column p_pluggablelogging            new_value s_pluggablelogging noprint
column p_sqlcmd                      new_value s_sqlcmd noprint
column p_compress_col                new_value s_compress_col noprint
column p_lob_compression_col         new_value s_lob_compression_col noprint
column p_lob_part_compression_col    new_value s_lob_part_compression_col noprint
column p_lob_subpart_compression_col new_value s_lob_subpart_compression_col noprint
column p_lob_dedup_col               new_value s_lob_dedup_col noprint
column p_lob_part_dedup_col          new_value s_lob_part_dedup_col noprint
column p_lob_subpart_dedup_col       new_value s_lob_subpart_dedup_col noprint
column p_lss_owner                   new_value s_lss_owner noprint
column p_index_visibility            new_value s_index_visibility noprint
column p_io_function_sql             new_value s_io_function_sql noprint
column p_app_join_pdbsinfo_cond      new_value s_app_join_pdbsinfo_cond noprint
column p_app_join_dbsum_cond         new_value s_app_join_dbsum_cond noprint
column p_session_type                new_value s_session_type noprint
column p_px_servers_execs_delta      new_value s_px_servers_execs_delta noprint
column p_px_servers_executions       new_value s_px_servers_executions noprint
column p_force_matching_sig          new_value s_force_matching_sig noprint
column p_sqlstats_dir                new_value s_sqlstats_dir noprint
column p_sqlstats_ver                new_value s_sqlstats_ver noprint
column p_statsosstatname             new_value s_statsosstatname noprint

column p_banner_ver_col              new_value s_banner_ver_col noprint


WITH banner_full AS (
  SELECT count(1) AS cnt 
  FROM dba_tab_columns
  WHERE table_name ='V_$VERSION'
    AND column_name = 'BANNER_FULL')
SELECT CASE WHEN bf.cnt = 1 THEN 'BANNER_FULL' ELSE 'BANNER' END AS p_banner_ver_col
FROM banner_full bf;



prompt -- Define some session info for the extraction -- BEGIN
-- Define some session info for the extraction -- BEGIN
BEGIN
SELECT host_name     hostnc,
       instance_name instnc
INTO :v_host,
     :v_instance 
FROM v$instance;
END;
/

BEGIN
SELECT name dbname INTO :v_dbname
FROM   v$database;
END;
/

SELECT owner AS p_lss_owner FROM dba_objects WHERE object_name = 'LOGSTDBY$SKIP_SUPPORT';

BEGIN
SELECT RTRIM(SUBSTR('&s_tag',INSTR('&s_tag','_',1,5)+1), '.csv') horanc INTO :v_hora from dual;
END;
/

BEGIN
SELECT substr(replace(version,'.',''),0,3) dbversion INTO :v_dbversion
FROM v$instance;
END;
/

BEGIN
  :v_pkey := :v_host || '_' || :v_dbname || '_' || :v_hora;
END;
/

COLUMN t_sql_cmd   NEW_VALUE  s_sql_cmd NOPRINT
COLUMN t_machine   NEW_VALUE  s_machine NOPRINT
COLUMN MACHINE FORMAT A60


SELECT  CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '&AWRDIR./sqlcmd10.sql' ELSE '&AWRDIR./sqlcmd12.sql' END as t_sql_cmd,
        CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 'has.machine' END as t_machine,
        CASE WHEN :v_dbversion LIKE '101'                          THEN '1'       ELSE '''FOREGROUND''' END as p_session_type,
        CASE WHEN :v_dbversion LIKE '101'                          THEN '0'       ELSE 'px_servers_execs_delta' END as p_px_servers_execs_delta,
        CASE WHEN :v_dbversion LIKE '101'                          THEN '0'       ELSE 'px_servers_executions' END as p_px_servers_executions,
        CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 'force_matching_signature' END as p_force_matching_sig,
        CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN 'sqlstats111.sql' ELSE 'sqlstats.sql' END as p_sqlstats_ver,
        CASE WHEN upper(:v_statssrc) = 'AWR'                       THEN 'sql/extracts/awr/' ELSE 'sql/extracts/statspack/' END as p_sqlstats_dir,
        CASE WHEN :v_dbversion LIKE '101'                          THEN '@&STATSPACKDIR/osstatsname.sql' ELSE 'stats$osstatname' END as p_statsosstatname
FROM DUAL;




-- Define some session info for the extraction -- END


-- Determine how we will transform the data_type column based on database version. --BEGIN
COLUMN p_data_type_exp NEW_VALUE s_data_type_exp noprint
COLUMN p_ora9ind NEW_VALUE s_ora9ind noprint
SELECT CASE WHEN  :v_dbversion LIKE '9%' THEN 'data_type_col_9i.sql'
            ELSE 'data_type_col_regex.sql'
       END as p_data_type_exp,
       CASE WHEN  :v_dbversion LIKE '9%' THEN '9i_'
            WHEN  :v_dbversion LIKE '101%' THEN '9i_'
            ELSE ''
       END AS p_ora9ind
FROM dual;
-- Determine how we will transform the data_type column based on database version. --END


-- Determine how we will get certain databasae and Dat Guard parameters based on databasee version. --BEGIN
COLUMN p_dg_valid_role         new_value s_dg_valid_role         noprint
COLUMN p_dg_verify             new_value s_dg_verify             noprint
COLUMN p_db_unique_name        new_value s_db_unique_name        noprint
COLUMN p_platform_name         new_value s_platform_name         noprint
SELECT
        '''N/A''' AS p_dg_valid_role,
        '''N/A''' AS p_dg_verify,
        'name'    AS p_db_unique_name,
        '''N/A''' AS p_platform_name
FROM DUAL
WHERE :v_dbversion LIKE '9%'
UNION
SELECT
        REPLACE('REPLACE(valid_role ,"|", " ")', chr(34), chr(39)) ,
        'verify'  ,
        'db_unique_name' AS p_db_unique_name,
        'platform_name'  AS p_platform_name
FROM DUAL
WHERE :v_dbversion NOT LIKE '9%';
-- Determine how we will get certain databasae and Dat Guard parameters based on databasee version. --END


-- Define a source id that will be consistent regardless of which RAC instance we are connected to.  --BEGIN
column vname new_value s_name noprint
SELECT min(object_name) AS vname
FROM dba_objects
WHERE object_name IN ('V$INSTANCE', 'GV$INSTANCE');

BEGIN
SELECT lower(i.host_name||'_'||&s_db_unique_name||'_'||d.dbid) INTO :v_dma_source_id
FROM (
	SELECT version, host_name
	FROM &&s_name
	WHERE instance_number = (SELECT min(instance_number) FROM &&s_name) ) i, v$database d;
END;
/
-- Define a source id that will be consistent regardless of which RAC instance we are connected to.  --END


-- Determine if we are in a container database, and if it supports editioning.  --BEGIN
var lv_tblprefix VARCHAR2(3);
var lv_is_container NUMBER;
var lv_editionable_col  VARCHAR2(20);
var lv_tenancy          VARCHAR2(40);
var lv_db_container_col VARCHAR2(30);
var lv_cdb_join_cond    VARCHAR2(30);
var lv_pdb_join_cond    VARCHAR2(30);

DECLARE
  cnt NUMBER;
BEGIN
  -- Defaults for non-container DBs
  :lv_tblprefix := 'dba';
  :lv_is_container := 0;
  :lv_editionable_col := '''N/A''';
  :lv_tenancy := 'op_collect_tenancy_single.sql';
  :lv_db_container_col := '''N/A''';
  :lv_cdb_join_cond := 'AND 1=1';
  :lv_pdb_join_cond := 'AND 1=1';
  :v_app_join_pdbsinfo_cond := 'AND 1=1';
  :v_app_join_dbsum_cond := 'AND 1=1';

  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner ='SYS' AND table_name = 'V_$DATABASE' AND column_name = 'CDB';
  IF cnt > 0 THEN
    EXECUTE IMMEDIATE 'SELECT count(1) FROM v$database WHERE cdb = ''YES'' ' INTO cnt;
    IF cnt > 0 THEN
      :lv_tblprefix := 'cdb' ;
      :lv_is_container := 1;
      :lv_tenancy := 'op_collect_tenancy_multi.sql';
      :lv_db_container_col := 'cdb';
      :lv_cdb_join_cond := 'AND 1=1';
      :lv_pdb_join_cond := 'AND con_id = p.con_id';
      :v_app_join_pdbsinfo_cond := 'AND con_id = p.con_id';
    END IF;
  END IF;

  SELECT count(1) INTO cnt  FROM dba_tab_columns WHERE owner ='SYS' AND table_name = 'DBA_OBJECTS' AND column_name ='EDITIONABLE';
  IF cnt > 0 THEN :lv_editionable_col := 'EDITIONABLE';
  END IF;
END;
/

SELECT :lv_tblprefix AS p_tblprefix,
       :lv_is_container AS p_is_container,
       :lv_editionable_col AS p_editionable_col,
       :lv_tenancy AS p_tenancy,
       :lv_db_container_col as p_db_container_col,
       :lv_cdb_join_cond as p_cdb_join_cond,
       :lv_pdb_join_cond as p_pdb_join_cond,
       :v_app_join_pdbsinfo_cond as p_app_join_pdbsinfo_cond,
       :v_app_join_dbsum_cond as p_app_join_dbsum_cond
FROM DUAL;
/

-- Determine if we are in a container database, and if it supports editioning.  --END

-- Determine if the database version supports the 'default_value' column in v$parameter --BEGIN
-- and if it supports the 'logging' column in dba_pbs.

DECLARE
  cnt NUMBER;
BEGIN
  :v_pdb_logging_flag := 'N';
  :v_dflt_value_flag := 'N';
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner ='SYS' AND table_name ='V_$SYSTEM_PARAMETER' AND column_name ='DEFAULT_VALUE';
  IF cnt = 1 THEN
    :v_dflt_value_flag := 'Y';
  END IF;

  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner = 'SYS' AND table_name ='DBA_PDBS' AND column_name ='LOGGING';
  IF cnt = 1 THEN
    :v_pdb_logging_flag := 'Y';
  END IF;
END;
/

SELECT CASE WHEN :v_dflt_value_flag = 'N' THEN '''N/A''' ELSE 'DEFAULT_VALUE' END as p_dbparam_dflt_col ,
       CASE WHEN :v_pdb_logging_flag = 'N' THEN  '''N/A''' ELSE 'LOGGING' END AS p_pluggablelogging,
       CASE WHEN :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN 'sqlcmd10g.sql' ELSE 'sqlcmd.sql' END AS p_sqlcmd
FROM DUAL;
-- Determine if the database version supports the 'default_value' column in v$parameter --END


-- Determine if we can check for table compression.  BEGIN
DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_TABLES' AND column_name ='COMPRESS_FOR';
  IF cnt = 1 THEN :v_compress_col := 'COMPRESS_FOR';
  ELSE
    SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_TABLES' AND column_name = 'COMPRESSION';
    IF cnt = 1 THEN :v_compress_col := 'COMPRESSION';
    END IF;
  END IF;
END;
/

SELECT :v_compress_col AS p_compress_col FROM dual;
-- Determine if we can check for table compression.  END


-- Determine if we can collect IO stats based on requested performance stats source.   BEGIN
DECLARE
cnt NUMBER;
BEGIN
  SELECT SUM(cnt) INTO cnt FROM (
    SELECT count(1) FROM dba_views WHERE (view_name = 'DBA_HIST_IOSTAT_FUNCTION' AND :v_statssrc = 'awr')
    UNION
    SELECT count(1) FROM dba_tables WHERE (table_name ='STATS$IOSTAT_FUNCTION_NAME' AND :v_statssrc = 'statspack' AND OWNER ='PERFSTAT')
  );
  IF (cnt > 0 ) THEN :v_io_function_sql := 'iofunction.sql';
  ELSE
    :v_io_function_sql := 'noop.sql';
  END IF;
END;
/

SELECT :v_io_function_sql AS p_io_function_sql FROM dual;
-- Determine if we can collect IO stats based on requested performance stats source.   END


-- Get the DBID - BEGIN
-- Determine if we are running on a standby database and if so, check if it is recording AWR stats via DBMS_UMF.
-- Fail if running on a standby without DBMS_UMF configured.
-- Defines from where we will get the dbid for collection.
set serveroutput on
DECLARE cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM v$database WHERE database_role = 'PHYSICAL STANDBY';
  IF (cnt != 0) THEN
    SELECT count(1) INTO cnt FROM all_objects WHERE object_name = 'DBMS_UMF';
    IF (cnt > 0) THEN :v_umfflag := 'dbms_umf.get_node_id_local';
    ELSE raise_application_error(-20002, 'This physical standby database is not configured to store historical performance data or this user does not have correct privileges.');
    END IF;
  ELSE :v_umfflag := 'dbid';
  END IF;
END;
/

-- Use the results from above to set the variable we will use to get the dbid.
SELECT
:v_umfflag umf_test
FROM dual
/

-- Finally get the dbid from the determined source.
SELECT &s_umf_test p_dbid
INTO :v_dbid
FROM   v$database
/
BEGIN
SELECT to_number(&s_dbid) INTO :v_dbid FROM DUAL;
END;
/
-- Get the DBID - END


-- Set up columns for base LOB data -- BEGIN

column c_con_id   new_value s_c_con_id   noprint
column t_con_id   new_value s_t_con_id   noprint
column l_con_id   new_value s_l_con_id   noprint
column tp_con_id  new_value s_tp_con_id  noprint
column tsp_con_id new_value s_tsp_con_id noprint
column lp_con_id  new_value s_lp_con_id  noprint
column lsp_con_id new_value s_lsp_con_id noprint
column s_con_id   new_value s_s_con_id   noprint

column t_segment_created   new_value  s_t_segment_created noprint
column tp_segment_created  new_value  s_tp_segment_created noprint
column lp_segment_created  new_value  s_lp_segment_created noprint
column tsp_segment_created new_value  s_tsp_segment_created noprint
column lsp_segment_created new_value  s_lsp_segment_created noprint


SELECT CASE WHEN &s_is_container. != 0 THEN 'c.con_id'   ELSE '''N/A''' END as c_con_id,
       CASE WHEN &s_is_container. != 0 THEN 't.con_id'   ELSE '''N/A''' END as t_con_id,
       CASE WHEN &s_is_container. != 0 THEN 'l.con_id'   ELSE '''N/A''' END as l_con_id,
       CASE WHEN &s_is_container. != 0 THEN 'tp.con_id'  ELSE '''N/A''' END as tp_con_id,
       CASE WHEN &s_is_container. != 0 THEN 'tsp.con_id' ELSE '''N/A''' END as tsp_con_id,
       CASE WHEN &s_is_container. != 0 THEN 'lp.con_id'  ELSE '''N/A''' END as lp_con_id,
       CASE WHEN &s_is_container. != 0 THEN 'lsp.con_id' ELSE '''N/A''' END as lsp_con_id,
       CASE WHEN &s_is_container. != 0 THEN 's.con_id'   ELSE '''N/A''' END as s_con_id
FROM DUAL;

SELECT  CASE WHEN :v_dbversion LIKE '9%' OR :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 't.segment_created'   END as t_segment_created,
        CASE WHEN :v_dbversion LIKE '9%' OR :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 'tp.segment_created'  END as tp_segment_created,
        CASE WHEN :v_dbversion LIKE '9%' OR :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 'lp.segment_created'  END as lp_segment_created,
        CASE WHEN :v_dbversion LIKE '9%' OR :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 'tsp.segment_created' END as tsp_segment_created,
        CASE WHEN :v_dbversion LIKE '9%' OR :v_dbversion LIKE '10%' OR  :v_dbversion = '111' THEN '''N/A''' ELSE 'lsp.segment_created' END as lsp_segment_created
FROM DUAL;

-- Set up columns for base LOB data -- END


-- Determine if this version of the database supports LOB compression and set the substitution variables -- BEGIN
DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_LOBS' AND column_name = 'COMPRESSION';
  IF cnt = 1 THEN
    :v_lob_compression_col         := 'l.compression';
    :v_lob_part_compression_col    := 'lp.compression';
    :v_lob_subpart_compression_col := 'lsp.compression';
    :v_lob_dedup_col               := 'l.deduplication';
    :v_lob_part_dedup_col          := 'lp.deduplication';
    :v_lob_subpart_dedup_col       := 'lsp.deduplication';
  ELSE
    :v_lob_compression_col         := '''N/A''';
    :v_lob_part_compression_col    := '''N/A''';
    :v_lob_subpart_compression_col := '''N/A''';
    :v_lob_dedup_col               := '''N/A''';
    :v_lob_part_dedup_col          := '''N/A''';
    :v_lob_subpart_dedup_col       := '''N/A''';
  END IF;
END;
/

SELECT
:v_lob_compression_col         AS p_lob_compression_col ,
:v_lob_part_compression_col    AS p_lob_part_compression_col ,
:v_lob_subpart_compression_col AS p_lob_subpart_compression_col ,
:v_lob_dedup_col               AS p_lob_dedup_col ,
:v_lob_part_dedup_col          AS p_lob_part_dedup_col ,
:v_lob_subpart_dedup_col       AS p_lob_subpart_dedup_col
FROM DUAL;

-- Determine if this version of the database supports LOB compression and set the substitution variables -- END


-- Determine if this version of the database supports invisible indexes -- BEGIN
DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_INDEXES' AND column_name = 'VISIBILITY';
  IF cnt = 1 THEN
    :v_index_visibility := 'VISIBILITY';
  ELSE
    :v_index_visibility := '''N/A''';
  END IF;
END;
/

SELECT :v_index_visibility AS p_index_visibility FROM DUAL;

-- Determine if this version of the database supports invisible indexes -- END


-- Determine columns to select for tabletypes query -- BEGIN
VARIABLE xml_select_sql VARCHAR2(100);
COLUMN p_xml_select new_value s_xml_select noprint

DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt
  FROM &s_tblprefix._views
  WHERE view_name = upper('&s_tblprefix._XML_TABLES');

  IF cnt > 0 THEN
    :xml_select_sql := '&s_tblprefix._XML_TABLES';
  ELSE
    :xml_select_sql := '(SELECT NULL AS con_id, NULL AS owner FROM dual WHERE 1=2)';
  END IF;
END;
/

SELECT :xml_select_sql AS p_xml_select FROM dual;

-- Determine columns to select for tabletypes query -- END 



-- Determine columns to select for tabletypes detail query -- BEGIN
VARIABLE xml_select_dtl_sql VARCHAR2(100);
COLUMN p_xml_select_dtl new_value s_xml_select_dtl noprint

DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt
  FROM &s_tblprefix._views
  WHERE view_name = upper('&s_tblprefix._XML_TABLES');

  IF cnt > 0 THEN
    :xml_select_dtl_sql := '&s_tblprefix._XML_TABLES';
  ELSE
    :xml_select_dtl_sql := '(SELECT NULL AS con_id, NULL AS owner, NULL AS table_name FROM dual WHERE 1=2)';
  END IF;
END;
/

SELECT :xml_select_dtl_sql AS p_xml_select_dtl FROM dual;

-- Determine columns to select for tabletypes detail query -- END


-- This is where we determine which source (AWR, STATSPACK or NONE) we will use for performance metrics -- BEGiN
-- and which snaps we will collect.
variable v_stats_prompt VARCHAR2(100);
variable v_info_prompt VARCHAR2(200);
column sp_script new_value p_sp_script noprint
column info_prompt new_value s_info_prompt noprint

set termout on
set serveroutput on
DECLARE
  cnt NUMBER;
  l_tab_name VARCHAR2(100) := 'NONE';
  l_col_name VARCHAR2(100);
  the_sql VARCHAR2(1000) := 'NONE';
  table_does_not_exist EXCEPTION;
  PRAGMA EXCEPTION_INIT (table_does_not_exist, -00942);
BEGIN
  -- Set default performance metrics to NONE.
  :v_stats_prompt  := 'prompt_nostats.sql';

  -- Use AWR repository if requested.
  IF :v_statssrc = 'awr' THEN
     l_tab_name := 'DBA_HIST_SNAPSHOT';
     l_col_name := 'begin_interval_time';
     :v_stats_prompt := 'prompt_awr.sql';

  -- If STATSPACK has been requested, check that it is installed and permissions granted.
  ELSE IF :v_statssrc = 'statspack' THEN
         SELECT count(1) INTO cnt FROM all_tables WHERE owner ='PERFSTAT' AND table_name IN ('STATS$OSSTAT', 'STATS$OSSTATNAME', 'STATS$SNAPSHOT', 'STATS$SQL_SUMMARY', 'STATS$SYSSTAT', 'STATS$SYSTEM_EVENT', 'STATS$SYS_TIME_MODEL', 'STATS$TIME_MODEL_STATNAME');

         -- If we have access to STATSPACK, use STATSPACK as the source of performance metrics
 	 IF cnt = 8 THEN
           --:v_stats_prompt := 'op_collect_statspack.sql';
           :v_stats_prompt := 'prompt_statspack.sql';
           :v_statssrc := 'statspack';
           l_tab_name := 'STATS$SNAPSHOT';
           l_col_name := 'snap_time';
           dbms_output.put_line('Verified access to the STATSPACK tables.');
         ELSE
              l_tab_name := 'NONE' ;
              :v_stats_prompt  := 'prompt_nostats.sql';
              :v_statssrc := 'nostats';
              dbms_output.put_line('There is no access to the STATSPACK tables so cannot collect performance data.');
         END IF;
       -- If instructed to not collect performance metrics, do not collect stats.
       ELSE IF  :v_statssrc = 'nostats' THEN
              :v_stats_prompt  := 'prompt_nostats.sql';
              dbms_output.put_line('Requested to skip collection of performance stats.');
            -- If we get here, then there was a problem.
            ELSE l_tab_name :=  'ERROR - Unexpected parameter: ' || :v_statssrc;
            END IF;
       END IF;
  END IF;

  BEGIN
    IF l_tab_name = 'NONE' THEN
        dbms_output.put_line('No performance data will be collected.');
        :v_statssrc := 'nostats';
    ELSE
      -- Verify there are metrics to collect.
      BEGIN
        the_sql := 'SELECT count(1) FROM ' || upper(l_tab_name) || ' WHERE rownum < 2' ;
        -- dbms_output.put_line(the_sql);
        EXECUTE IMMEDIATE the_sql INTO cnt;
        IF cnt = 0 THEN
            dbms_output.put_line('No data found in ' ||  upper(l_tab_name) || '.  No performance data will be collected.');
            :v_stats_prompt := 'promt_nostats.sql';
            l_tab_name := 'NONE';
            :v_statssrc := 'nostats';
        END IF;
        EXCEPTION WHEN table_does_not_exist THEN
          RAISE_APPLICATION_ERROR(-20002, 'This user does not have SELECT privileges on ' || upper(l_tab_name) || '.  Please ensure the grants_wrapper.sql script has been executed for this user.');
      END;
    END IF;
  END;
  IF (l_tab_name != 'NONE' AND l_tab_name NOT LIKE 'ERROR%') THEN
     -- Get the snapshot range for AWR stats.
     IF l_tab_name = 'DBA_HIST_SNAPSHOT' THEN
       THE_SQL := 'SELECT min(snap_id) , max(snap_id) FROM ' || l_tab_name || ' WHERE ' || l_col_name || ' >= (sysdate- :v_statsWindow ) AND dbid = :v_dbid ';
       -- dbms_output.put_Line(the_sql);
       -- dbms_output.put_line(:v_statsWindow);
       -- dbms_output.put_line(:v_dbid);
       EXECUTE IMMEDIATE the_sql INTO  :v_min_snapid, :v_max_snapid USING :v_statsWindow,  :v_dbid ;
       IF :v_min_snapid IS NULL THEN
          dbms_output.put_line('Warning: No DBA_HIST snapshots found within the last ' || :v_statsWindow || ' days.  No performance data will be extracted.');
          :v_min_snapid := -1;
          :v_max_snapid := -1;
          :v_info_prompt := 'without performance data';
          :v_statssrc := 'nostats';
       ELSE
          :v_info_prompt := 'between snaps ' || :v_min_snapid || ' and ' || :v_max_snapid;
       END IF;
     ELSE
       -- Get the snapshot range for STATSPACK stats.
       THE_SQL := 'SELECT min(snap_time) , max(snap_time) FROM ' || l_tab_name || ' WHERE ' || l_col_name || ' >= (sysdate- :v_statsWindow ) AND dbid = :v_dbid ';
       EXECUTE IMMEDIATE the_sql INTO  :v_min_snaptime, :v_max_snaptime USING :v_statsWindow, :v_dbid ;
       IF :v_min_snaptime IS NULL THEN
          dbms_output.put_line('Warning: No STATSPACK snapshots found within the last ' || :v_statsWindow || ' days.  No performance data will be extracted.');
          :v_min_snaptime := sysdate;
          :v_max_snaptime := sysdate;
          :v_info_prompt := 'without performance data';
       ELSE
          :v_info_prompt := 'between  ' || :v_min_snaptime || ' and ' || :v_max_snaptime;
       END IF;
     END IF;
  ELSE
     :v_info_prompt := 'without performance data';
  END IF;
END;
/
-- set termout off
SELECT NVL(:v_min_snapid, -1) min_snapid, NVL(:v_max_snapid, -1) max_snapid, NVL(:v_min_snaptime, SYSDATE) min_snaptime, NVL(:v_max_snaptime, SYSDATE) max_snaptime,  :v_stats_prompt sp_script, :v_info_prompt info_prompt INTO :v_min_snapid, :v_max_snapid, :v_min_snaptime, :v_max_snaptime FROM dual;

BEGIN
SELECT '&s_min_snapid', '&s_max_snapid', '&s_min_snaptime', '&s_max_snaptime'
INTO :v_min_snapid, :v_max_snapid, :v_min_snaptime, :v_max_snaptime
FROM DUAL;
END;
/

set termout on
begin
dbms_output.put_line('Collecting data for database ' || :v_dbname || ' ' ||  :v_dbid || ' &s_info_prompt');
end;
/

set termout &TERMOUTOFF

COLUMN min_snapid clear
COLUMN max_snapid clear
COLUMN min_snaptime clear
COLUMN max_snaptime clear

-- This is where we determine which source (AWR, STATSPACK or NONE) we will use for performance metrics -- END



-- This is where we set the substitution variables for working within container databases. -- BEGIN
column a_con_id new_value s_a_con_id noprint
column b_con_id new_value s_b_con_id noprint
column c_con_id new_value s_c_con_id noprint
column d_con_id new_value s_d_con_id noprint
column p_con_id new_value s_p_con_id noprint
column h_con_id new_value s_h_con_id noprint
SELECT CASE WHEN &s_is_container != 0 THEN 'a.con_id' ELSE '''N/A''' END as a_con_id,
       CASE WHEN &s_is_container != 0 THEN 'b.con_id' ELSE '''N/A''' END as b_con_id,
       CASE WHEN &s_is_container != 0 THEN 'c.con_id' ELSE '''N/A''' END as c_con_id,
       CASE WHEN &s_is_container != 0 THEN 'd.con_id' ELSE '''N/A''' END as d_con_id,
       CASE WHEN &s_is_container != 0 THEN 'p.con_id' ELSE '''N/A''' END as p_con_id,
       CASE WHEN &s_is_container != 0 THEN 'FORMAT 999999' ELSE 'FORMAT A6' END as h_con_id
FROM DUAL;

column CON_ID &s_h_con_id
-- This is where we set the substitution variables for working within container databases. -- END

-- Set manual_unique_id
BEGIN
  :v_manual_unique_id :=  chr(39) || '&s_manualUniqueId' || chr(39);
END;
/

column c_statssrc new_value s_statssrc NOPRINT
SELECT :v_statssrc as c_statssrc FROM DUAL;

exec dbms_output.put_line('Stats source is &s_statssrc + ' ||  :v_statssrc);

-- Session settings for output
set numwidth 48
column v_dma_source_id format a100
column v_dma_manual_id format a100
column dma_source_id format a100
column dma_manual_id format a100
column pkey format a100

@set_columns.sql



