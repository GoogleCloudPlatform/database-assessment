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
*/

whenever sqlerror exit failure
whenever oserror exit failure

set verify off
set feedback off
set echo off
accept dbusername char prompt "Please enter the DB Local Username(Or CDB Username) to receive all required grants: "

DECLARE 
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_users WHERE upper(username) = upper('&&dbusername');
  IF cnt = 0 THEN
    raise_application_error(-1917, 'User &&dbusername does not exist. please verify the username and ensure the account is created.');
  END IF;
END;
/

set feedback on
prompt
prompt
prompt Granting required privileges for user &&dbusername
set feedback off

/*
accept dbusername char prompt "Please enter the DB Local Username(Or CDB Username) to receive all required grants: "
*/

/*
        Use db_awr_license variable to OVERRIDE license usage.
        i.e. db_awr_license='Y' when you want to use AWR views irrespective of if you have license to run AWR or not
        Keep db_awr_license='N' if you don't want to query any AWR tables.
*/


def db_awr_license='Y'

var v_db_version varchar2(3)
var v_awr_license varchar2(3)
var v_statspack varchar2(3)
var v_is_container varchar2(3)
var v_use_umf varchar2(3)

var v_db_script varchar2(100)
var v_con_script varchar2(100)
var v_sp_script varchar2(100)

column db_script  new_val DB_SCRIPT_NAME noprint
column con_script new_val CON_SCRIPT_NAME noprint
column sp_script  new_val SP_SCRIPT_NAME noprint

/* Find Current Database Version */
BEGIN
SELECT
    CASE
        WHEN version LIKE '12%' OR version LIKE '19.%' OR version LIKE '20.%' OR version LIKE '21%'
        THEN '12+'
        ELSE '11g'
    END ver
 INTO :v_db_version
 FROM v$instance
 WHERE ROWNUM=1;
END;
/

/* Find AWR Licensed Usage */
BEGIN
SELECT
    CASE
        WHEN (value LIKE 'DIAG' OR value LIKE 'TUNING' ) OR '&db_awr_license'='Y'
        THEN 'AWR'
        ELSE 'NOAWR'
    END CASE 
 INTO :v_awr_license
 FROM v$parameter
WHERE UPPER(name) = 'CONTROL_MANAGEMENT_PACK_ACCESS';
dbms_output.put_line('AWR License flag = ' || :v_awr_license);
END;
/

/* Is there a statpack installation */
DECLARE 
  CNT NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_users WHERE username ='PERFSTAT';
  IF cnt > 0 THEN 
    :v_statspack := 'Y';
  END IF;
END;
/

/* Is this a container database */
DECLARE
  CNT NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_tab_columns WHERE owner = 'SYS' AND table_name = 'V_$DATABASE' AND column_name = 'CDB';
  IF cnt > 0 THEN
    EXECUTE IMMEDIATE 'SELECT cdb FROM v_$database' INTO :v_is_container;
  END IF;
END;
/

/* Using UMF to collect stats from standby */
DECLARE 
  CNT NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_objects WHERE owner ='SYS' AND object_name ='DBMS_UMF';
  IF cnt > 0 THEN
    :v_use_umf := 'Y';
  END IF;
END;
/


BEGIN
 CASE
   WHEN :v_db_version = '11g' AND :v_awr_license = 'AWR' THEN
        :v_db_script := 'minimum_select_grants_for_targets_ONLY_FOR_11g.sql';
   WHEN :v_db_version = '12+' AND :v_awr_license = 'AWR' THEN
        :v_db_script := 'minimum_select_grants_for_targets_12c_AND_ABOVE.sql';
   ELSE 
        :v_db_script := 'noop.sql "AWR objects"';
 END CASE;
 CASE
   WHEN :v_statspack = 'Y' THEN
        :v_sp_script := 'minimum_select_grants_for_statspack.sql';
   ELSE 
        :v_sp_script := 'noop.sql "STATSPACK objects"';
   END CASE;
 CASE
   WHEN :v_is_container = 'YES' THEN
        :v_con_script := 'minimum_select_grants_for_targets_12c_AND_ABOVE_containers.sql';
   ELSE
        :v_con_script := 'noop.sql "container objects"';
 END CASE;
END;
/

select :v_db_script db_script, :v_sp_script sp_script, :v_con_script con_script from dual;

@&SP_SCRIPT_NAME
@&DB_SCRIPT_NAME
@&CON_SCRIPT_NAME

DECLARE 
  the_sql VARCHAR2(200);
BEGIN
  IF :v_use_umf = 'Y' THEN
    the_sql :=  'GRANT EXECUTE ON sys.dbms_umf TO &&dbusername';
    EXECUTE IMMEDIATE the_sql;
  END IF;
END;
/

exit;
