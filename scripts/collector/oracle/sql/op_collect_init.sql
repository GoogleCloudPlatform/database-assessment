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
define dtrange = 30
define colspr = '|'

@@op_set_sql_env.sql 

set headsep off
set trimspool on
set lines 32000
set pagesize 0 embedded on
set feed off
set underline off
set verify off
set head on
set scan on
set pause off
set wrap on
set echo off
set appinfo 'DB MIGRATION ASSESSMENT' 
set colsep '|'
set timing off
set time off
alter session set nls_numeric_characters='.,';

set termout on
whenever sqlerror exit failure
whenever oserror continue


variable minsnap NUMBER;
variable maxsnap NUMBER;
variable umfflag VARCHAR2(100);
variable pdb_logging_flag VARCHAR2(1);
variable dflt_value_flag  VARCHAR2(1);
variable b_compress_col VARCHAR2(20);

variable b_lob_compression_col         VARCHAR2(30);
variable b_lob_part_compression_col    VARCHAR2(30);
variable b_lob_subpart_compression_col VARCHAR2(30);
variable b_lob_dedup_col               VARCHAR2(30);
variable b_lob_part_dedup_col          VARCHAR2(30);
variable b_lob_subpart_dedup_col       VARCHAR2(30);

variable b_index_visibility            VARCHAR2(30);

variable b_io_function_sql             VARCHAR2(20);

column instnc new_value v_inst noprint
column hostnc new_value v_host noprint
column horanc new_value v_hora noprint
column dbname new_value v_dbname noprint
column dbversion new_value v_dbversion noprint
column min_snapid new_value v_min_snapid noprint
column max_snapid new_value v_max_snapid noprint
column umf_test new_value v_umf_test noprint
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

SELECT host_name     hostnc,
       instance_name instnc
FROM   v$instance
/

SELECT name dbname
FROM   v$database
/


select RTRIM(SUBSTR('&v_tag',INSTR('&v_tag','_',1,5)+1), '.csv') horanc from dual;

SELECT substr(replace(version,'.',''),0,3) dbversion
from v$instance
/

/*
WITH control_params AS 
(
SELECT 'dba' as tblprefix,
       0 as is_container,
       '''N/A''' as editionable_col,
       '112' as this_version,
       'op_collect_nopluggable_info.sql' as do_pluggable,
       '''N/A''' as db_container_col
FROM DUAL
UNION
SELECT 'cdb' as tblprefix,
       1 as is_container,
       'EDITIONABLE' as editionable_col,
       'OTHER' as this_version,
       'op_collect_pluggable_info.sql' as do_pluggable,
       'cdb'  as db_container_col
FROM DUAL
)
SELECT tblprefix AS p_tblprefix,
       is_container AS p_is_container,
       editionable_col AS p_editionable_col, 
       do_pluggable AS p_dopluggable,
       db_container_col as p_db_container_col
FROM control_params WHERE ('&v_dbversion'  = '112' AND this_version = '&v_dbversion') 
                       OR ('&v_dbversion' != '112' AND this_version = 'OTHER')
*/

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
  ELSE IF  '&v_dbversion'  LIKE '11%' OR  '&v_dbversion'  LIKE '10%' THEN
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


DECLARE
cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tables WHERE table_name = 'DBA_HIST_IOSTAT_FUNCTION';
  IF cnt = 1 OR (cnt = 1 AND '&v_dodiagnostics' = 'usediagnostics') THEN :b_io_function_sql := 'iofunction.sql';
  ELSE 
    :b_io_function_sql := 'noop.sql';
  END IF;
END;
/

SELECT :b_io_function_sql AS p_io_function_sql FROM dual;


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

SELECT
:umfflag umf_test
FROM dual
/


SELECT &v_umf_test p_dbid
FROM   v$database
/

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
BEGIN 
  :sp  := 'prompt_nostatspack.sql';
  IF '&v_dodiagnostics' = 'usediagnostics' THEN 
     l_tab_name := 'DBA_HIST_SNAPSHOT'; 
     l_col_name := 'begin_interval_time';
  ELSE IF '&v_dodiagnostics' = 'nodiagnostics' THEN
         SELECT count(1) INTO cnt FROM all_tables WHERE owner ='PERFSTAT';
         IF cnt > 0 THEN 
           :sp := 'op_collect_statspack.sql';
           l_tab_name := 'STATS$SNAPSHOT'; 
           l_col_name := 'snap_time';
         END IF;
       ELSE l_tab_name :=  'ERROR - Unexpected parameter: &v_dodiagnostics';
       END IF;
  END IF; 
  BEGIN
    SELECT count(1) INTO cnt FROM user_tab_privs WHERE table_name = upper(l_tab_name);
    IF cnt = 0 THEN
      IF l_tab_name ='---' THEN
        dbms_output.put_line('This user does not have SELECT privileges on DBA_HIST_SNAPSHOT or STATS$SNAPSHOT.  No performance data will be collected.');
      ELSE
        RAISE_APPLICATION_ERROR(-20002, 'This user does not have SELECT privileges on ' || l_tab_name || '.  Please ensure the grants_wrapper.sql script has been executed for this user.');
      END IF;
    END IF;
  END;
  IF (l_tab_name != '---' AND l_tab_name NOT LIKE 'ERROR%') THEN
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
     :v_info_prompt := 'without performance data';
  END IF;
END;
/
set termout off
SELECT NVL(:minsnap, -1) min_snapid, NVL(:maxsnap, -1) max_snapid, :sp sp_script, :v_info_prompt info_prompt FROM dual;

set termout on
PROMPT Collecting data for database &v_dbname '&&v_dbid' &p_info_prompt
PROMPT

set termout &TERMOUTOFF

COLUMN min_snapid clear
COLUMN max_snapid clear

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

set numwidth 48

