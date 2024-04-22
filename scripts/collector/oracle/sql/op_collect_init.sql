/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

This script access Automatic Repository Workload (AWR) views in the database dictionary.
Please ensure you have proper licensing. For more information consult Oracle Support Doc ID 1490798.1

*/
prompt Param1 = &1

define version = '&1'
define dtrange = &v_statsWindow
define colspr = '|'

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

-- For the min and max snaps to collect
variable minsnap NUMBER;
variable minsnaptime VARCHAR2(20);
variable maxsnap NUMBER;
variable maxsnaptime VARCHAR2(20);

-- To handle collection from within a Dataguard standby
variable umfflag VARCHAR2(100);

-- To handle column 'LOGGING' in 'DBA_PDBS'.  Depends on Oracle version
variable pdb_logging_flag VARCHAR2(1);

-- To handle column 'DEFAULT_VALUE' in 'V_$SYSTEM_PARAMETER' 
variable dflt_value_flag  VARCHAR2(1);

-- to handle column 'COMPRESS_FOR' in 'DBA_TABLES'. Depends on Oracle version
variable b_compress_col VARCHAR2(20);

variable b_lob_compression_col         VARCHAR2(30);
variable b_lob_part_compression_col    VARCHAR2(30);
variable b_lob_subpart_compression_col VARCHAR2(30);
variable b_lob_dedup_col               VARCHAR2(30);
variable b_lob_part_dedup_col          VARCHAR2(30);
variable b_lob_subpart_dedup_col       VARCHAR2(30);

variable b_index_visibility            VARCHAR2(30);

variable b_io_function_sql             VARCHAR2(20);

variable v_dma_source_id               VARCHAR2(100);
variable v_manual_unique_id            VARCHAR2(100);

-- Session settings to support creating substitution variables for the scripts.
column instnc new_value v_inst noprint
column hostnc new_value v_host noprint
column horanc new_value v_hora noprint
column dbname new_value v_dbname noprint
column dbversion new_value v_dbversion noprint
column min_snapid new_value v_min_snapid noprint
column min_snaptime new_value v_min_snaptime noprint
column max_snapid new_value v_max_snapid noprint
column max_snaptime new_value v_max_snaptime noprint
column umf_test new_value v_umf_test noprint
--column p_dma_source_id new_value v_dma_source_id noprint
column p_dbid new_value v_dbid noprint
column p_tblprefix new_value v_tblprefix noprint
column p_is_container new_value v_is_container noprint
column p_dbparam_dflt_col new_value v_dbparam_dflt_col noprint
column p_editionable_col new_value v_editionable_col noprint
column p_dopluggable new_value v_dopluggable noprint
column p_db_container_col new_value v_db_container_col noprint
column p_pluggablelogging new_value v_pluggablelogging noprint
column p_sqlcmd new_value v_sqlcmd noprint
column p_compress_col new_value v_compress_col noprint
column p_lob_compression_col new_value v_lob_compression_col noprint
column p_lob_part_compression_col new_value v_lob_part_compression_col noprint
column p_lob_subpart_compression_col new_value v_lob_subpart_compression_col noprint
column p_lob_dedup_col new_value v_lob_dedup_col noprint
column p_lob_part_dedup_col new_value v_lob_part_dedup_col noprint
column p_lob_subpart_dedup_col new_value v_lob_subpart_dedup_col noprint
column p_index_visibility new_value v_index_visibility noprint
column p_io_function_sql new_value v_io_function_sql noprint

-- Define some session info for the extraction -- BEGIN
SELECT host_name     hostnc,
       instance_name instnc
FROM   v$instance
/

SELECT name dbname
FROM   v$database
/


SELECT RTRIM(SUBSTR('&v_tag',INSTR('&v_tag','_',1,5)+1), '.csv') horanc from dual;

SELECT substr(replace(version,'.',''),0,3) dbversion
FROM v$instance
/
BEGIN
  :v_pkey := '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora';
END;
/
  
-- Define some session info for the extraction -- END


-- Determine how we will transform the data_type column based on database version. --BEGIN
COLUMN p_data_type_exp NEW_VALUE v_data_type_exp noprint
COLUMN p_ora9ind NEW_VALUE v_ora9ind noprint
SELECT CASE WHEN  '&v_dbversion' LIKE '9%' THEN 'data_type_col_9i.sql'
            ELSE 'data_type_col_regex.sql'
       END as p_data_type_exp,
       CASE WHEN  '&v_dbversion' LIKE '9%' THEN '9i_'
            ELSE ''
       END AS p_ora9ind
FROM dual;
-- Determine how we will transform the data_type column based on database version. --END


-- Determine how we will get certain databasae and Dat Guard parameters based on databasee version. --BEGIN
COLUMN p_dg_valid_role         new_value v_dg_valid_role         noprint
COLUMN p_dg_verify             new_value v_dg_verify             noprint
COLUMN p_db_unique_name        new_value v_db_unique_name        noprint
COLUMN p_platform_name         new_value v_platform_name         noprint
SELECT
        '''N/A''' AS p_dg_valid_role,
        '''N/A''' AS p_dg_verify,
        'name'    AS p_db_unique_name,
        '''N/A''' AS p_platform_name
FROM DUAL
WHERE '&v_dbversion' LIKE '9%'
UNION
SELECT
        REPLACE('REPLACE(valid_role ,"|", " ")', chr(34), chr(39)) ,
        'verify'  ,
        'db_unique_name' AS p_db_unique_name,
        'platform_name'  AS p_platform_name
FROM DUAL
WHERE '&v_dbversion' NOT LIKE '9%';
-- Determine how we will get certain databasae and Dat Guard parameters based on databasee version. --END


-- Define a source id that will be consistent regardless of which RAC instance we are connected to.  --BEGIN
column vname new_value v_name noprint
SELECT min(object_name) AS vname
FROM dba_objects
WHERE object_name IN ('V$INSTANCE', 'GV$INSTANCE');

BEGIN
SELECT lower(i.host_name||'_'||&v_db_unique_name||'_'||d.dbid) INTO :v_dma_source_id 
FROM ( 
	SELECT version, host_name
	FROM &&v_name 
	WHERE instance_number = (SELECT min(instance_number) FROM &&v_name) ) i, v$database d;
END;
/
-- Define a source id that will be consistent regardless of which RAC instance we are connected to.  --END


-- Determine if we are in a container database, and if it supports editioning.  --BEGIN
var lv_tblprefix VARCHAR2(3);
var lv_is_container NUMBER;
var lv_editionable_col  VARCHAR2(20);
var lv_do_pluggable     VARCHAR2(40);
var lv_db_container_col VARCHAR2(30);

DECLARE
  cnt NUMBER;
BEGIN
  :lv_tblprefix := 'dba';
  :lv_is_container := 0;
  :lv_editionable_col := '''N/A''';
  :lv_do_pluggable := 'op_collect_nopluggable_info.sql';
  :lv_db_container_col := '''N/A''';

  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner ='SYS' AND table_name = 'V_$DATABASE' AND column_name = 'CDB';
  IF cnt > 0 THEN
    EXECUTE IMMEDIATE 'SELECT count(1) FROM v$database WHERE cdb = ''YES'' ' INTO cnt;
    IF cnt > 0 THEN
      :lv_tblprefix := 'cdb' ;
      :lv_is_container := 1;
      :lv_do_pluggable := 'op_collect_pluggable_info.sql';
      :lv_db_container_col := 'cdb';
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
       :lv_do_pluggable AS p_dopluggable,
       :lv_db_container_col as p_db_container_col
FROM DUAL;
/
-- Determine if we are in a container database, and if it supports editioning.  --END

-- Determine if the database version supports the 'default_value' column in v$parameter --BEGIN
-- and iff it supports the 'logging' column in dba_pbs. 
DECLARE 
  cnt NUMBER;
BEGIN
  IF '&v_dbversion'  = '121' THEN
    SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner ='SYS' AND table_name ='V_$SYSTEM_PARAMETER' AND column_name ='DEFAULT_VALUE';
    IF cnt = 0 THEN
      :dflt_value_flag := 'N';
    ELSE
      :dflt_value_flag := 'Y';
    END IF;

    SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner = 'SYS' AND table_name ='DBA_PDBS' AND column_name ='LOGGING';
    IF cnt = 0 THEN
      :pdb_logging_flag := 'N';
    ELSE
      :pdb_logging_flag := 'Y';
    END IF;
  ELSE IF  '&v_dbversion'  LIKE '11%' OR  '&v_dbversion'  LIKE '10%'  OR  '&v_dbversion'  LIKE '9%'  THEN
          :dflt_value_flag := 'N';
          :pdb_logging_flag := 'N';
       END IF;
  END IF;
END;
/

SELECT CASE WHEN :dflt_value_flag = 'N' THEN '''N/A''' ELSE 'DEFAULT_VALUE' END as p_dbparam_dflt_col ,
       CASE WHEN :pdb_logging_flag = 'N' THEN  '''N/A''' ELSE 'LOGGING' END AS p_pluggablelogging,
       CASE WHEN '&v_dbversion' LIKE '10%' OR  '&v_dbversion' = '111' THEN 'sqlcmd10g.sql' ELSE 'sqlcmd.sql' END AS p_sqlcmd
FROM DUAL;
-- Determine if the database version supports the 'default_value' column in v$parameter --END


-- Determine if we can check for table compression.  BEGIN
DECLARE 
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_TABLES' AND column_name ='COMPRESS_FOR';
  IF cnt = 1 THEN :b_compress_col := 'COMPRESS_FOR';
  ELSE
    SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_TABLES' AND column_name = 'COMPRESSION';
    IF cnt = 1 THEN :b_compress_col := 'COMPRESSION';
    END IF;
  END IF;
END;
/

SELECT :b_compress_col AS p_compress_col FROM dual;
-- Determine if we can check for table compression.  END


-- Determine if we can collect IO stats based on requested performance stats source.   BEGIN
DECLARE
cnt NUMBER;
BEGIN
  SELECT SUM(cnt) INTO cnt FROM (
    SELECT count(1) FROM dba_views WHERE (view_name = 'DBA_HIST_IOSTAT_FUNCTION' AND '&v_dodiagnostics' = 'usediagnostics')
    UNION
    SELECT count(1) FROM dba_tables WHERE (table_name ='STATS$IOSTAT_FUNCTION_NAME' AND '&v_dodiagnostics' = 'nodiagnostics' AND OWNER ='PERFSTAT')
  );
  IF (cnt > 0 ) THEN :b_io_function_sql := 'iofunction.sql';
  ELSE
    :b_io_function_sql := 'noop.sql';
  END IF;
END;
/

SELECT :b_io_function_sql AS p_io_function_sql FROM dual;
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
    IF (cnt > 0) THEN :umfflag := 'dbms_umf.get_node_id_local';
    ELSE raise_application_error(-20002, 'This physical standby database is not configured to store historical performance data or this user does not have correct privileges.');
    END IF;
  ELSE :umfflag := 'dbid';
  END IF;
END;
/

-- Use the results from above to set the variable we will use to get the dbid.
SELECT
:umfflag umf_test
FROM dual
/

-- Finally get the dbid from the determined source.
SELECT &v_umf_test p_dbid
FROM   v$database
/
-- Get the DBID - END


-- Determine if this version of the database supports LOB compression and set the substitution variables -- BEGIN
DECLARE 
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_LOBS' AND column_name = 'COMPRESSION';
  IF cnt = 1 THEN
    :b_lob_compression_col         := 'l.compression';
    :b_lob_part_compression_col    := 'lp.compression';
    :b_lob_subpart_compression_col := 'lsp.compression';
    :b_lob_dedup_col               := 'l.deduplication';
    :b_lob_part_dedup_col          := 'lp.deduplication';
    :b_lob_subpart_dedup_col       := 'lsp.deduplication';
  ELSE
    :b_lob_compression_col         := '''N/A''';
    :b_lob_part_compression_col    := '''N/A''';
    :b_lob_subpart_compression_col := '''N/A''';
    :b_lob_dedup_col               := '''N/A''';
    :b_lob_part_dedup_col          := '''N/A''';
    :b_lob_subpart_dedup_col       := '''N/A''';
  END IF;
END;
/

SELECT
:b_lob_compression_col         AS p_lob_compression_col ,
:b_lob_part_compression_col    AS p_lob_part_compression_col ,
:b_lob_subpart_compression_col AS p_lob_subpart_compression_col ,
:b_lob_dedup_col               AS p_lob_dedup_col ,
:b_lob_part_dedup_col          AS p_lob_part_dedup_col ,
:b_lob_subpart_dedup_col       AS p_lob_subpart_dedup_col
FROM DUAL;

-- Determine if this version of the database supports LOB compression and set the substitution variables -- END


-- Determine if this version of the database supports invisible indexes -- BEGIN
DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE table_name = 'DBA_INDEXES' AND column_name = 'VISIBILITY';
  IF cnt = 1 THEN
    :b_index_visibility := 'VISIBILITY';
  ELSE
    :b_index_visibility := '''N/A''';
  END IF;
END;
/

SELECT :b_index_visibility AS p_index_visibility FROM DUAL;

-- Determine if this version of the database supports invisible indexes -- END


-- This is where we determine which source (AWR, STATSPACK or NONE) we will use for performance metrics -- BEGiN
-- and which snaps we will collect.
variable sp VARCHAR2(100);
variable v_info_prompt VARCHAR2(200);
column sp_script new_value p_sp_script noprint
column info_prompt new_value p_info_prompt noprint

set termout on
set serveroutput on
DECLARE
  cnt NUMBER;
  l_tab_name VARCHAR2(100) := '---';
  l_col_name VARCHAR2(100);
  the_sql VARCHAR2(1000) := '---';
  table_does_not_exist EXCEPTION;
  PRAGMA EXCEPTION_INIT (table_does_not_exist, -00942);

BEGIN 
  -- Set default performance metrics to NONE.
  :sp  := 'prompt_nostatspack.sql';

  -- Use AWR repository if requested.
  IF '&v_dodiagnostics' = 'usediagnostics' THEN 
     l_tab_name := 'DBA_HIST_SNAPSHOT'; 
     l_col_name := 'begin_interval_time';

  -- If STATSPACK has been requested, check that it is installed and permissions granted.
  ELSE IF '&v_dodiagnostics' = 'nodiagnostics' THEN
         SELECT count(1) INTO cnt FROM all_tables WHERE owner ='PERFSTAT' AND table_name IN ('STATS$OSSTAT', 'STATS$OSSTATNAME', 'STATS$SNAPSHOT', 'STATS$SQL_SUMMARY', 'STATS$SYSSTAT', 'STATS$SYSTEM_EVENT', 'STATS$SYS_TIME_MODEL', 'STATS$TIME_MODEL_STATNAME');
         -- If we have access to STATSPACK, use STATSPACK as the source of performance metrics
 	 IF cnt = 8 THEN 
           :sp := 'op_collect_statspack.sql';
           l_tab_name := 'STATS$SNAPSHOT';
           l_col_name := 'snap_time';
         END IF;
       -- If instructed to not collect performance metrics, do not collect stats.
       ELSE IF  '&v_dodiagnostics' = 'nostatspack' THEN
              :sp  := 'prompt_nostatspack.sql';
            -- If we get here, then there was a problem.
            ELSE l_tab_name :=  'ERROR - Unexpected parameter: &v_dodiagnostics';
            END IF;
       END IF;
  END IF; 
  BEGIN
    IF l_tab_name = '---' THEN
        dbms_output.put_line('No performance data will be collected.');
    ELSE

      -- Verify there are metrics to collect.	
      BEGIN 
        EXECUTE IMMEDIATE 'SELECT count(1) FROM ' || upper(l_tab_name) || ' WHERE rownum < 2' INTO cnt ;
        IF cnt = 0 THEN
            dbms_output.put_line('No data found in ' ||  upper(l_tab_name) || '.  No performance data will be collected.');
        END IF;
        EXCEPTION WHEN table_does_not_exist THEN
          RAISE_APPLICATION_ERROR(-20002, 'This user does not have SELECT privileges on ' || upper(l_tab_name) || '.  Please ensure the grants_wrapper.sql script has been executed for this user.');
      END;
    END IF;
  END;
  IF (l_tab_name != '---' AND l_tab_name NOT LIKE 'ERROR%') THEN
     -- Get the snapshot range for AWR stats.
     IF l_tab_name = 'DBA_HIST_SNAPSHOT' THEN
       THE_SQL := 'SELECT min(snap_id) , max(snap_id) FROM ' || l_tab_name || ' WHERE ' || l_col_name || ' >= (sysdate- &&dtrange ) AND dbid = :1 ';
       EXECUTE IMMEDIATE the_sql INTO  :minsnap, :maxsnap USING '&&v_dbid' ;
       IF :minsnap IS NULL THEN
          dbms_output.put_line('Warning: No snapshots found within the last &&dtrange days.  No performance data will be extracted.');
          :minsnap := -1;
          :maxsnap := -1;
          :v_info_prompt := 'without performance data';
       ELSE
          :v_info_prompt := 'between snaps ' || :minsnap || ' and ' || :maxsnap;
       END IF;
     ELSE
       -- Get the snapshot range for STATSPACE stats.
       THE_SQL := 'SELECT min(snap_time) , max(snap_time) FROM ' || l_tab_name || ' WHERE ' || l_col_name || ' >= (sysdate- &&dtrange ) AND dbid = :1 ';
       EXECUTE IMMEDIATE the_sql INTO  :minsnaptime, :maxsnaptime USING '&&v_dbid' ;
       IF :minsnaptime IS NULL THEN
          dbms_output.put_line('Warning: No snapshots found within the last &&dtrange days.  No performance data will be extracted.');
          :minsnaptime := sysdate;
          :maxsnaptime := sysdate;
          :v_info_prompt := 'without performance data';
       ELSE
          :v_info_prompt := 'between  ' || :minsnaptime || ' and ' || :maxsnaptime;
       END IF;
     END IF;
  ELSE
     :v_info_prompt := 'without performance data';
  END IF;
END;
/
set termout off
SELECT NVL(:minsnap, -1) min_snapid, NVL(:maxsnap, -1) max_snapid, NVL(:minsnaptime, SYSDATE) min_snaptime, NVL(:maxsnaptime, SYSDATE) max_snaptime,  :sp sp_script, :v_info_prompt info_prompt FROM dual;

set termout on
PROMPT Collecting data for database &v_dbname '&&v_dbid' &p_info_prompt
PROMPT

set termout &TERMOUTOFF

COLUMN min_snapid clear
COLUMN max_snapid clear
COLUMN min_snaptime clear
COLUMN max_snaptime clear

-- This is where we determine which source (AWR, STATSPACK or NONE) we will use for performance metrics -- END



-- This is where we set the substitution variables for working within container databases. -- BEGIN
column a_con_id new_value v_a_con_id noprint
column b_con_id new_value v_b_con_id noprint
column c_con_id new_value v_c_con_id noprint
column d_con_id new_value v_d_con_id noprint
column p_con_id new_value v_p_con_id noprint
column h_con_id new_value v_h_con_id noprint
SELECT CASE WHEN &v_is_container != 0 THEN 'a.con_id' ELSE '''N/A''' END as a_con_id,
       CASE WHEN &v_is_container != 0 THEN 'b.con_id' ELSE '''N/A''' END as b_con_id,
       CASE WHEN &v_is_container != 0 THEN 'c.con_id' ELSE '''N/A''' END as c_con_id,
       CASE WHEN &v_is_container != 0 THEN 'd.con_id' ELSE '''N/A''' END as d_con_id,
       CASE WHEN &v_is_container != 0 THEN 'p.con_id' ELSE '''N/A''' END as p_con_id,
       CASE WHEN &v_is_container != 0 THEN 'FORMAT 999999' ELSE 'FORMAT A6' END as h_con_id
FROM DUAL;

column CON_ID &v_h_con_id
-- This is where we set the substitution variables for working within container databases. -- END

-- Set manual_unique_id 
BEGIN
  :v_manual_unique_id :=  chr(39) || '&v_manualUniqueId' || chr(39);
END;
/


-- Session settings for output
set numwidth 48
column v_dma_source_id format a100
column v_dma_manual_id format a100
column dma_source_id format a100
column dma_manual_id format a100
