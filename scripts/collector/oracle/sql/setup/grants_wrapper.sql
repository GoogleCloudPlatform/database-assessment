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

prompt "Please enter the database local username (or CDB username) to receive all required grants. "
accept dbusername    char prompt "Enter exactly as defined in the database, upper/lower case must match: "
accept usediagnostics char default 'Y' prompt "Please enter Y or N to allow or disallow use of the Tuning and Diagnostic Pack (AWR/ASH) data (Y) "

DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM dba_users WHERE username = '&&dbusername';
  IF cnt = 0 THEN
    raise_application_error(-20001, 'User "&&dbusername" does not exist. please verify the username and ensure the account is created.');
  END IF;
END;
/


set serveroutput on size 50000
set termout on
set lines 200
set feedback off
whenever sqlerror exit failure
DECLARE
    TYPE rectype IS RECORD (
    objpriv varchar2(30),
    objowner varchar2(30),
    objname varchar2(30)
    );

    TYPE t_source_table_list IS
        TABLE OF rectype;

    TABLE_DOES_NOT_EXIST EXCEPTION;
    PRAGMA EXCEPTION_INIT(TABLE_DOES_NOT_EXIST, -00942);

    v_source_table_list t_source_table_list;

    v_table_owner       VARCHAR2(30);
    v_table_name        VARCHAR2(30);
    v_table_priv        VARCHAR2(30);
    v_cnt               NUMBER;
    v_err_ind           BOOLEAN := FALSE;

    v_infosep           VARCHAR2(100) := rpad('-', 100, '-');
    v_errsep            VARCHAR2(100) := rpad('!', 100, '!');

    PROCEDURE list_pdbs
    IS
      TYPE c_pdb_list_type IS REF CURSOR;
      v_pdb_list c_pdb_list_type;
      v_pdb_name VARCHAR2(128);
      v_pdb_count NUMBER := 0;
    BEGIN
      dbms_output.put_line(v_infosep);
      dbms_output.put_line('-- Privileges verified for the below pluggable databases:');
      OPEN v_pdb_list FOR 'SELECT pdb_name FROM cdb_pdbs WHERE pdb_name != :seedname ORDER BY 1' USING 'PDB$SEED';
      LOOP
        FETCH v_pdb_list INTO v_pdb_name;
        EXIT WHEN v_pdb_list%NOTFOUND;
        dbms_output.put_line('   ' || v_pdb_name);
        v_pdb_count := v_pdb_count + 1;
      END LOOP;
      IF v_pdb_count = 0 THEN
        dbms_output.put_line(v_errsep);
        dbms_output.put_line(v_errsep);
        dbms_output.put_line('-- This user has no access to pluggable databases.');
        dbms_output.put_line('-- Please execute the below ALTER USER statement in the container database.');
        dbms_output.put_line('ALTER USER "&dbusername"  SET CONTAINER_DATA=ALL CONTAINER = CURRENT;');
        dbms_output.put_line(v_errsep);
        dbms_output.put_line(v_errsep);
        raise_application_error(-20002, 'No access to pluggable database information');
      ELSE
        dbms_output.put_line(v_infosep);
      END IF;
    END;


    PROCEDURE grant_privs(p_priv_list t_source_table_list)
    IS
      v_sql VARCHAR2(2000);
    BEGIN

     FOR x IN p_priv_list.first..p_priv_list.last LOOP
        v_table_priv  :=  p_priv_list(x).objpriv;
        v_table_owner :=  p_priv_list(x).objowner;
        v_table_name  := p_priv_list(x).objname;

        BEGIN
          SELECT count(1)
          INTO v_cnt
          FROM dba_objects
          WHERE owner = v_table_owner
            AND object_name = v_table_name;

          IF v_cnt != 0 THEN
            v_sql := 'GRANT ' || v_table_priv || ' ON ' || v_table_owner || '.' || v_table_name || ' TO "&dbusername" ' ;
            dbms_output.put_line(v_sql || ';' );
            EXECUTE IMMEDIATE v_sql;
          END IF;
        END;
     END LOOP;

    SELECT count(1) INTO v_cnt FROM dba_tab_columns WHERE table_name ='V_$DATABASE' AND column_name ='CDB';
    IF (v_cnt > 0) THEN
       EXECUTE IMMEDIATE 'SELECT count(1) FROM v$containers' INTO v_cnt;
       IF (v_cnt > 1) THEN
         v_sql := 'ALTER USER  "&dbusername"  SET CONTAINER_DATA=ALL CONTAINER = CURRENT';
         dbms_output.put_line(v_sql || ';' );
         EXECUTE IMMEDIATE v_sql;
         list_pdbs;
       END IF;
    END IF;
    END;


    FUNCTION rectype_( p_objpriv VARCHAR2, p_objowner VARCHAR2, p_objname VARCHAR2) RETURN RECTYPE IS
      retval rectype;
    BEGIN
      retval.objpriv  := p_objpriv;
      retval.objowner := p_objowner;
      retval.objname  := p_objname;
      RETURN retval;
    END;

BEGIN

  -- The rectype entries in the code blocks below are parsed to generate documentation.
  -- Please follow the same format of one entry per line when adding new privileges.
  IF upper('&usediagnostics') = 'Y' THEN
  dbms_output.put_line('Granting privs for AWR/ASH data');
    v_source_table_list := t_source_table_list(
      rectype_('SELECT','SYS','CDB_HIST_ACTIVE_SESS_HISTORY'),
      rectype_('SELECT','SYS','CDB_HIST_IOSTAT_FUNCTION'),
      rectype_('SELECT','SYS','CDB_HIST_OSSTAT'),
      rectype_('SELECT','SYS','CDB_HIST_SNAPSHOT'),
      rectype_('SELECT','SYS','CDB_HIST_SQLSTAT'),
      rectype_('SELECT','SYS','CDB_HIST_SQLTEXT'),
      rectype_('SELECT','SYS','CDB_HIST_SYSMETRIC_HISTORY'),
      rectype_('SELECT','SYS','CDB_HIST_SYSMETRIC_SUMMARY'),
      rectype_('SELECT','SYS','CDB_HIST_SYSSTAT'),
      rectype_('SELECT','SYS','CDB_HIST_SYSTEM_EVENT'),
      rectype_('SELECT','SYS','CDB_HIST_SYS_TIME_MODEL'),
      rectype_('SELECT','SYS','DBA_HIST_ACTIVE_SESS_HISTORY'),
      rectype_('SELECT','SYS','DBA_HIST_IOSTAT_FUNCTION'),
      rectype_('SELECT','SYS','DBA_HIST_OSSTAT'),
      rectype_('SELECT','SYS','DBA_HIST_SNAPSHOT'),
      rectype_('SELECT','SYS','DBA_HIST_SQLSTAT'),
      rectype_('SELECT','SYS','DBA_HIST_SQLTEXT'),
      rectype_('SELECT','SYS','DBA_HIST_SYSMETRIC_HISTORY'),
      rectype_('SELECT','SYS','DBA_HIST_SYSMETRIC_SUMMARY'),
      rectype_('SELECT','SYS','DBA_HIST_SYSSTAT'),
      rectype_('SELECT','SYS','DBA_HIST_SYSTEM_EVENT'),
      rectype_('SELECT','SYS','DBA_HIST_SYS_TIME_MODEL')
      );
    grant_privs(v_source_table_list);
  END IF;

  v_source_table_list := t_source_table_list(
      rectype_('EXECUTE','SYS','DBMS_UMF'),
      rectype_('EXECUTE','SYS','DBMS_QOPATCH'),
      rectype_('SELECT','PERFSTAT','STATS$IOSTAT_FUNCTION_NAME'),
      rectype_('SELECT','PERFSTAT','STATS$IOSTAT_FUNCTION'),
      rectype_('SELECT','PERFSTAT','STATS$OSSTATNAME'),
      rectype_('SELECT','PERFSTAT','STATS$OSSTAT'),
      rectype_('SELECT','PERFSTAT','STATS$SNAPSHOT'),
      rectype_('SELECT','PERFSTAT','STATS$SQL_SUMMARY'),
      rectype_('SELECT','PERFSTAT','STATS$SYSSTAT'),
      rectype_('SELECT','PERFSTAT','STATS$SYSTEM_EVENT'),
      rectype_('SELECT','PERFSTAT','STATS$SYS_TIME_MODEL'),
      rectype_('SELECT','PERFSTAT','STATS$TIME_MODEL_STATNAME'),
      rectype_('SELECT','SYS','AUX_STATS$'),
      rectype_('SELECT','SYS','CDB_CONSTRAINTS'),
      rectype_('SELECT','SYS','CDB_CPU_USAGE_STATISTICS'),
      rectype_('SELECT','SYS','CDB_DATA_FILES'),
      rectype_('SELECT','SYS','CDB_DB_LINKS'),
      rectype_('SELECT','SYS','CDB_EXTERNAL_TABLES'),
      rectype_('SELECT','SYS','CDB_FEATURE_USAGE_STATISTICS'),
      rectype_('SELECT','SYS','CDB_FREE_SPACE'),
      rectype_('SELECT','SYS','CDB_HIGH_WATER_MARK_STATISTICS'),
      rectype_('SELECT','SYS','CDB_INDEXES'),
      rectype_('SELECT','SYS','CDB_LOB_PARTITIONS'),
      rectype_('SELECT','SYS','CDB_LOBS'),
      rectype_('SELECT','SYS','CDB_LOB_SUBPARTITIONS'),
      rectype_('SELECT','SYS','CDB_MVIEWS'),
      rectype_('SELECT','SYS','CDB_OBJECTS'),
      rectype_('SELECT','SYS','CDB_OBJECT_TABLES'),
      rectype_('SELECT','SYS','CDB_PART_TABLES'),
      rectype_('SELECT','SYS','CDB_PDBS'),
      rectype_('SELECT','SYS','CDB_SEGMENTS'),
      rectype_('SELECT','SYS','CDB_SERVICES'),
      rectype_('SELECT','SYS','CDB_SOURCE'),
      rectype_('SELECT','SYS','CDB_SYNONYMS'),
      rectype_('SELECT','SYS','CDB_TAB_COLS'),
      rectype_('SELECT','SYS','CDB_TAB_COLUMNS'),
      rectype_('SELECT','SYS','CDB_TABLESPACES'),
      rectype_('SELECT','SYS','CDB_TABLES'),
      rectype_('SELECT','SYS','CDB_TAB_PARTITIONS'),
      rectype_('SELECT','SYS','CDB_TAB_SUBPARTITIONS'),
      rectype_('SELECT','SYS','CDB_TEMP_FILES'),
      rectype_('SELECT','SYS','CDB_TRIGGERS'),
      rectype_('SELECT','SYS','CDB_USERS'),
      rectype_('SELECT','SYS','CDB_VIEWS'),
      rectype_('SELECT','SYS','CDB_XML_TABLES'),
      rectype_('SELECT','SYS','CONTAINER$'),
      rectype_('SELECT','SYS','DBA_CONSTRAINTS'),
      rectype_('SELECT','SYS','DBA_CPU_USAGE_STATISTICS'),
      rectype_('SELECT','SYS','DBA_DATA_FILES'),
      rectype_('SELECT','SYS','DBA_DB_LINKS'),
      rectype_('SELECT','SYS','DBA_EXTERNAL_TABLES'),
      rectype_('SELECT','SYS','DBA_FEATURE_USAGE_STATISTICS'),
      rectype_('SELECT','SYS','DBA_FREE_SPACE'),
      rectype_('SELECT','SYS','DBA_HIGH_WATER_MARK_STATISTICS'),
      rectype_('SELECT','SYS','DBA_INDEXES'),
      rectype_('SELECT','SYS','DBA_LOB_PARTITIONS'),
      rectype_('SELECT','SYS','DBA_LOBS'),
      rectype_('SELECT','SYS','DBA_LOB_SUBPARTITIONS'),
      rectype_('SELECT','SYS','DBA_MVIEWS'),
      rectype_('SELECT','SYS','DBA_OBJECTS'),
      rectype_('SELECT','SYS','DBA_OBJECT_TABLES'),
      rectype_('SELECT','SYS','DBA_PART_TABLES'),
      rectype_('SELECT','SYS','DBA_REGISTRY_SQLPATCH'),
      rectype_('SELECT','SYS','DBA_SEGMENTS'),
      rectype_('SELECT','SYS','DBA_SERVICES'),
      rectype_('SELECT','SYS','DBA_SOURCE'),
      rectype_('SELECT','SYS','DBA_SYNONYMS'),
      rectype_('SELECT','SYS','DBA_TAB_COLS'),
      rectype_('SELECT','SYS','DBA_TAB_COLUMNS'),
      rectype_('SELECT','SYS','DBA_TABLESPACES'),
      rectype_('SELECT','SYS','DBA_TABLES'),
      rectype_('SELECT','SYS','DBA_TAB_PARTITIONS'),
      rectype_('SELECT','SYS','DBA_TAB_SUBPARTITIONS'),
      rectype_('SELECT','SYS','DBA_TEMP_FILES'),
      rectype_('SELECT','SYS','DBA_TRIGGERS'),
      rectype_('SELECT','SYS','DBA_USERS'),
      rectype_('SELECT','SYS','DBA_VIEWS'),
      rectype_('SELECT','SYS','DBA_XML_TABLES'),
      rectype_('SELECT','SYS','GV_$ARCHIVE_DEST'),
      rectype_('SELECT','SYS','GV_$ARCHIVED_LOG'),
      rectype_('SELECT','SYS','GV_$DATABASE'),
      rectype_('SELECT','SYS','GV_$INSTANCE'),
      rectype_('SELECT','SYS','GV_$PARAMETER'),
      rectype_('SELECT','SYS','GV_$PDBS'),
      rectype_('SELECT','SYS','GV_$PGASTAT'),
      rectype_('SELECT','SYS','GV_$PROCESS'),
      rectype_('SELECT','SYS','GV_$SGASTAT'),
      rectype_('SELECT','SYS','GV_$SYSTEM_PARAMETER'),
      rectype_('SELECT','SYS','NLS_DATABASE_PARAMETERS'),
      rectype_('SELECT','SYS','OBJ$'),
      rectype_('SELECT','SYS','REGISTRY$HISTORY'),
      rectype_('SELECT','SYS','V_$ARCHIVE_DEST'),
      rectype_('SELECT','SYS','V_$DATABASE'),
      rectype_('SELECT','SYS','V_$EVENT_NAME'),
      rectype_('SELECT','SYS','V_$INSTANCE'),
      rectype_('SELECT','SYS','V_$LOGFILE'),
      rectype_('SELECT','SYS','V_$LOG_HISTORY'),
      rectype_('SELECT','SYS','V_$LOG'),
      rectype_('SELECT','SYS','V_$PARAMETER'),
      rectype_('SELECT','SYS','V_$PDBS'),
      rectype_('SELECT','SYS','V_$PGASTAT'),
      rectype_('SELECT','SYS','V_$RMAN_BACKUP_JOB_DETAILS'),
      rectype_('SELECT','SYS','V_$SGASTAT'),
      rectype_('SELECT','SYS','V_$SQLCOMMAND'),
      rectype_('SELECT','SYS','V_$SYSTEM_PARAMETER'),
      rectype_('SELECT','SYS','V_$TEMP_SPACE_HEADER'),
      rectype_('SELECT','SYS','V_$VERSION'),
      rectype_('SELECT','SYSTEM','LOGSTDBY$SKIP_SUPPORT')
    );
  grant_privs(v_source_table_list);

END;
/
exit
