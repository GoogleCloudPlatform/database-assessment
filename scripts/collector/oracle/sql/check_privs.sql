set serveroutput on
set termout on
set lines 100
set feedback off
whenever sqlerror exit failure
spool privs.sql
DECLARE
    TYPE rectype IS RECORD (
    objowner varchar2(30),
    objname varchar2(30),
    objpriv varchar2(30)
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
    v_curr_user         VARCHAR2(30);
    v_err_ind           BOOLEAN := FALSE;
    v_container_db      BOOLEAN := FALSE;

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
      dbms_output.put_line('-- This extract will include the below pluggable databases:');
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
        dbms_output.put_line('ALTER USER  ' || user || ' SET CONTAINER_DATA=ALL CONTAINER = CURRENT;');
        dbms_output.put_line(v_errsep);
        dbms_output.put_line(v_errsep);
        raise_application_error(-20002, 'No access to pluggable database information');
      ELSE
        dbms_output.put_line(v_infosep);
      END IF;
    END;

    PROCEDURE check_privs(p_priv_list t_source_table_list) 
    IS
      v_container_clause VARCHAR2(100) := '';
    BEGIN
        IF v_container_db THEN v_container_clause := 'ALTER USER  ' || user || ' SET CONTAINER_DATA=ALL CONTAINER = CURRENT;';
        END IF;
        FOR x IN p_priv_list.first..p_priv_list.last LOOP
        v_table_owner :=  p_priv_list(x).objowner;
        v_table_name  := p_priv_list(x).objname;
        v_table_priv  :=  p_priv_list(x).objpriv;
        IF v_table_priv = 'SELECT' THEN
          BEGIN
            EXECUTE IMMEDIATE 'SELECT 1 FROM '
                              || v_table_owner ||'.'
                              || v_table_name
                              || ' WHERE rownum < 2 '
            INTO v_cnt;
            EXCEPTION 
            WHEN NO_DATA_FOUND THEN CONTINUE;
            WHEN TABLE_DOES_NOT_EXIST THEN 
              IF v_err_ind = FALSE THEN 
                dbms_output.put_line(v_infosep);
                v_err_ind := TRUE;
              END IF;
              dbms_output.put_line('GRANT ' || v_table_priv || ' ON ' || v_table_owner || '.' || v_table_name || ' TO ' || v_curr_user || ';' );
          END;  
          END IF;
        IF v_table_priv = 'EXECUTE' THEN
        BEGIN
          SELECT count(1) 
          INTO v_cnt 
          FROM user_tab_privs 
          WHERE owner = v_table_owner
            AND table_name = v_table_name
            AND privilege = v_table_priv;
            
          IF v_cnt = 0 THEN
            dbms_output.put_line('GRANT ' || v_table_priv || ' ON ' || v_table_owner || '.' || v_table_name || ' TO ' || v_curr_user || ';' );
            v_err_ind := TRUE;
          END IF;  
        END;
        END IF;
    END LOOP;
    IF v_err_ind THEN
        dbms_output.put_line(v_container_clause);
        dbms_output.put_line(v_infosep);
        dbms_output.put_line('-- Please execute the above grants to user ' || v_curr_user || ' and retry the exract.');
        raise_application_error(-20003, 'Insufficient privileges to complete the extract.  Please see above list.');
    ELSE dbms_output.put_line('Privilege check passed');
    END IF;
    IF v_container_db THEN
       list_pdbs;
    END IF;
  END;
  
      
    function rectype_(p_objowner VARCHAR2, p_objname VARCHAR2, p_objpriv VARCHAR2) RETURN RECTYPE IS
      retval rectype;
    BEGIN
      retval.objowner := p_objowner;
      retval.objname  := p_objname;
      retval.objpriv  := p_objpriv;
      RETURN retval;
    END;
    
BEGIN
  BEGIN
    SELECT count(1) INTO v_cnt FROM all_tab_columns WHERE OWNER ='SYS' AND table_name ='V_$DATABASE' AND column_name ='CDB';
    IF v_cnt = 1 THEN v_container_db := TRUE;
    END IF;
  EXCEPTION WHEN OTHERS THEN
    raise_application_error(-20001, 'This user must have SELECT privileges on V$DATABASE to continue.');
  END;

  SELECT user INTO v_curr_user FROM dual;
  IF v_container_db THEN
    v_source_table_list := t_source_table_list(
      rectype_('SYS','CDB_CONSTRAINTS','SELECT'),
      rectype_('SYS','CDB_CPU_USAGE_STATISTICS','SELECT'),
      rectype_('SYS','DBA_CPU_USAGE_STATISTICS','SELECT'),
      rectype_('SYS','CDB_DATA_FILES','SELECT'),
      rectype_('SYS','CDB_DB_LINKS','SELECT'),
      rectype_('SYS','CDB_EXTERNAL_TABLES','SELECT'),
      rectype_('SYS','CDB_FEATURE_USAGE_STATISTICS','SELECT'),
      rectype_('SYS','CDB_HIGH_WATER_MARK_STATISTICS','SELECT'),
      rectype_('SYS','CDB_HIST_ACTIVE_SESS_HISTORY','SELECT'),
      rectype_('SYS','CDB_HIST_IOSTAT_FUNCTION','SELECT'),
      rectype_('SYS','CDB_HIST_OSSTAT','SELECT'),
      rectype_('SYS','CDB_HIST_SNAPSHOT','SELECT'),
      rectype_('SYS','CDB_HIST_SQLSTAT','SELECT'),
      rectype_('SYS','CDB_HIST_SQLTEXT','SELECT'),
      rectype_('SYS','CDB_HIST_SYSMETRIC_HISTORY','SELECT'),
      rectype_('SYS','CDB_HIST_SYSMETRIC_SUMMARY','SELECT'),
      rectype_('SYS','CDB_HIST_SYSSTAT','SELECT'),
      rectype_('SYS','CDB_HIST_SYSTEM_EVENT','SELECT'),
      rectype_('SYS','CDB_HIST_SYS_TIME_MODEL','SELECT'),
      rectype_('SYS','CDB_INDEXES','SELECT'),
      rectype_('SYS','CDB_LOBS','SELECT'),
      rectype_('SYS','CDB_LOB_PARTITIONS','SELECT'),
      rectype_('SYS','CDB_LOB_SUBPARTITIONS','SELECT'),
      rectype_('SYS','CDB_MVIEWS','SELECT'),
      rectype_('SYS','CDB_OBJECTS','SELECT'),
      rectype_('SYS','DBA_OBJECTS','SELECT'),
      rectype_('SYS','CDB_SEGMENTS','SELECT'),
      rectype_('SYS','CDB_PDBS','SELECT'),
      rectype_('SYS','CDB_SOURCE','SELECT'),
      rectype_('SYS','CDB_TABLES','SELECT'),
      rectype_('SYS','CDB_TAB_COLS','SELECT'),
      rectype_('SYS','CDB_TAB_COLUMNS','SELECT'),
      rectype_('SYS','CDB_TAB_PARTITIONS','SELECT'),
      rectype_('SYS','CDB_TAB_SUBPARTITIONS','SELECT'),
      rectype_('SYS','CDB_TEMP_FILES','SELECT'),
      rectype_('SYS','CDB_TRIGGERS','SELECT'),
      rectype_('SYS','CDB_USERS','SELECT'),
      rectype_('SYS','CDB_VIEWS','SELECT'),
      rectype_('SYS','DBA_VIEWS','SELECT'),
      rectype_('SYS','GV_$ARCHIVED_LOG','SELECT'),
      rectype_('SYS','GV_$ARCHIVE_DEST','SELECT'),
      rectype_('SYS','GV_$INSTANCE','SELECT'),
      rectype_('SYS','GV_$PARAMETER','SELECT'),
      rectype_('SYS','NLS_DATABASE_PARAMETERS','SELECT'),
      rectype_('SYS','V_$DATABASE','SELECT'),
      rectype_('SYS','V_$INSTANCE','SELECT'),
      rectype_('SYS','V_$LOG','SELECT'),
      rectype_('SYS','V_$LOGFILE','SELECT'),
      rectype_('SYS','V_$LOG_HISTORY','SELECT'),
      rectype_('SYS','V_$PARAMETER','SELECT'),
      rectype_('SYS','V_$PDBS','SELECT'),
      rectype_('SYS','V_$PGASTAT','SELECT'),
      rectype_('SYS','V_$RMAN_BACKUP_JOB_DETAILS','SELECT'),
      rectype_('SYS','V_$SGASTAT','SELECT'),
      rectype_('SYS','V_$SQLCOMMAND','SELECT'),
      rectype_('SYS','V_$VERSION','SELECT'),
      rectype_('SYSTEM','LOGSTDBY$SKIP_SUPPORT','SELECT')
      );
  ELSE
      v_source_table_list := t_source_table_list(
      rectype_('SYS','DBA_CONSTRAINTS','SELECT'),
      rectype_('SYS','DBA_CPU_USAGE_STATISTICS','SELECT'),
      rectype_('SYS','DBA_DATA_FILES','SELECT'),
      rectype_('SYS','DBA_DB_LINKS','SELECT'),
      rectype_('SYS','DBA_EXTERNAL_TABLES','SELECT'),
      rectype_('SYS','DBA_FEATURE_USAGE_STATISTICS','SELECT'),
      rectype_('SYS','DBA_HIGH_WATER_MARK_STATISTICS','SELECT'),
      rectype_('SYS','DBA_HIST_ACTIVE_SESS_HISTORY','SELECT'),
      rectype_('SYS','DBA_HIST_IOSTAT_FUNCTION','SELECT'),
      rectype_('SYS','DBA_HIST_OSSTAT','SELECT'),
      rectype_('SYS','DBA_HIST_SNAPSHOT','SELECT'),
      rectype_('SYS','DBA_HIST_SQLSTAT','SELECT'),
      rectype_('SYS','DBA_HIST_SQLTEXT','SELECT'),
      rectype_('SYS','DBA_HIST_SYSMETRIC_HISTORY','SELECT'),
      rectype_('SYS','DBA_HIST_SYSMETRIC_SUMMARY','SELECT'),
      rectype_('SYS','DBA_HIST_SYSSTAT','SELECT'),
      rectype_('SYS','DBA_HIST_SYSTEM_EVENT','SELECT'),
      rectype_('SYS','DBA_HIST_SYS_TIME_MODEL','SELECT'),
      rectype_('SYS','DBA_INDEXES','SELECT'),
      rectype_('SYS','DBA_LOBS','SELECT'),
      rectype_('SYS','DBA_LOB_PARTITIONS','SELECT'),
      rectype_('SYS','DBA_LOB_SUBPARTITIONS','SELECT'),
      rectype_('SYS','DBA_MVIEWS','SELECT'),
      rectype_('SYS','DBA_OBJECTS','SELECT'),
      rectype_('SYS','DBA_SEGMENTS','SELECT'),
      rectype_('SYS','DBA_SOURCE','SELECT'),
      rectype_('SYS','DBA_TABLES','SELECT'),
      rectype_('SYS','DBA_TAB_COLS','SELECT'),
      rectype_('SYS','DBA_TAB_COLUMNS','SELECT'),
      rectype_('SYS','DBA_TAB_PARTITIONS','SELECT'),
      rectype_('SYS','DBA_TAB_SUBPARTITIONS','SELECT'),
      rectype_('SYS','DBA_TEMP_FILES','SELECT'),
      rectype_('SYS','DBA_TRIGGERS','SELECT'),
      rectype_('SYS','DBA_USERS','SELECT'),
      rectype_('SYS','DBA_VIEWS','SELECT'),
      rectype_('SYS','GV_$ARCHIVED_LOG','SELECT'),
      rectype_('SYS','GV_$ARCHIVE_DEST','SELECT'),
      rectype_('SYS','GV_$INSTANCE','SELECT'),
      rectype_('SYS','GV_$PARAMETER','SELECT'),
      rectype_('SYS','NLS_DATABASE_PARAMETERS','SELECT'),
      rectype_('SYS','V_$DATABASE','SELECT'),
      rectype_('SYS','V_$INSTANCE','SELECT'),
      rectype_('SYS','V_$LOG','SELECT'),
      rectype_('SYS','V_$LOGFILE','SELECT'),
      rectype_('SYS','V_$LOG_HISTORY','SELECT'),
      rectype_('SYS','V_$PARAMETER','SELECT'),
      rectype_('SYS','V_$PGASTAT','SELECT'),
      rectype_('SYS','V_$RMAN_BACKUP_JOB_DETAILS','SELECT'),
      rectype_('SYS','V_$SGASTAT','SELECT'),
      rectype_('SYS','V_$SQLCOMMAND','SELECT'),
      rectype_('SYS','V_$VERSION','SELECT'),
      rectype_('SYSTEM','LOGSTDBY$SKIP_SUPPORT','SELECT')
      );
      
  END IF;

  check_privs(v_source_table_list); 
END;
/
spool off
exit

