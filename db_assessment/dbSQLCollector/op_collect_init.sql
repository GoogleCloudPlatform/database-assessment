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


define version = '&1'
define dtrange = 30
define colspr = '|'

clear col comp brea
set headsep off
set trimspool on
set lines 32000
set pagesize 50000
set feed off
set underline off
set verify off
set head on
set scan on
set pause off
set wrap on
set echo off
set appinfo 'OPTIMUS_PRIME'
set colsep '|'
set numwidth 48
set timing off
set time off

whenever sqlerror continue
whenever oserror continue

HOS echo define outputdir=$OP_OUTPUT_DIR > /tmp/dirs.sql
HOS echo define seddir=$BASE_DIR/db_assessment/dbSQLCollector >> /tmp/dirs.sql
HOS echo define v_tag=$V_TAG >> /tmp/dirs.sql
@/tmp/dirs.sql
select '&outputdir' as outputdir from dual;
select '&seddir' as seddir from dual;
select '&v_tag' as v_tag from dual;
HOS rm -rf /tmp/dirs.sql

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
column p_db_container_col new_value v_db_container_col

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


WITH control_params AS 
(
SELECT 'dba' as tblprefix,
       0 as is_container,
       '''N/A''' as dbparam_dflt_col,
       '''N/A''' as editionable_col,
       '112' as this_version,
       'op_collect_nopluggable_info.sql' as do_pluggable,
       '''N/A''' as db_container_col
FROM DUAL
UNION
SELECT 'cdb' as tblprefix,
       1 as is_container,
       'DEFAULT_VALUE' as dbparam_dflt_col,
       'EDITIONABLE' as editionable_col,
       'OTHER' as this_version,
       'op_collect_pluggable_info.sql' as do_pluggable,
       'cdb'  as db_container_col
FROM DUAL
)
SELECT tblprefix AS p_tblprefix,
       is_container AS p_is_container,
       dbparam_dflt_col AS p_dbparam_dflt_col,
       editionable_col AS p_editionable_col, 
       do_pluggable AS p_dopluggable,
       db_container_col as p_db_container_col
FROM control_params WHERE ('&v_dbversion'  = '112' AND this_version = '&v_dbversion') 
                       OR ('&v_dbversion' != '112' AND this_version = 'OTHER')
/

SELECT
CASE WHEN database_role = 'PHYSICAL STANDBY' THEN 'dbms_umf.get_node_id_local' ELSE 'dbid' END AS umf_test
FROM v$database;


SELECT &v_umf_test p_dbid
FROM   v$database
/


SELECT MIN(snap_id) min_snapid,
       MAX(snap_id) max_snapid
FROM   &v_tblprefix._hist_snapshot
WHERE  begin_interval_time > ( SYSDATE - '&&dtrange' )
AND dbid = '&&v_dbid'
/

PROMPT Collecting data for '&&v_dbid' between snaps &v_min_snapid and &v_max_snapid
PROMPT


COLUMN min_snapid clear
COLUMN max_snapid clear

column a_con_id new_value v_a_con_id noprint
column b_con_id new_value v_b_con_id noprint
column c_con_id new_value v_c_con_id noprint
SELECT CASE WHEN &v_is_container != 0 THEN 'a.con_id' ELSE '''N/A''' END as a_con_id,
       CASE WHEN &v_is_container != 0 THEN 'b.con_id' ELSE '''N/A''' END as b_con_id,
       CASE WHEN &v_is_container != 0 THEN 'c.con_id' ELSE '''N/A''' END as c_con_id
FROM DUAL;

