REM /***************************************
REM * Copyright (c) 2024 Oracle and/or its affiliates.
REM * Licensed under the Universal Permissive License v 1.0 as shown at https://oss.oracle.com/licenses/upl.
REM ***************************************
REM * OEE Group Extract StandAlone v5.1
REM ****************************************/

set longchunksize 99999999
-- set pages 0
set LONG 99999999 
set echo OFF
set feed OFF
set lines 20000
set head off
set serveroutput OFF
set trimspool ON
set underline off
set verify off


-- make connection persistent to number formats and conversions 

alter session set NLS_NUMERIC_CHARACTERS = '.,' ;
ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';

-- make connection persistent to number formats and conversions


VAR output_clob CLOB
VAR MPACK_DBINFO_clob CLOB
VAR mpack_summary_clob CLOB
VAR MPACK_TRANSACTIONS_clob CLOB
VAR MPACK_USERSCONNECTED_clob CLOB
VAR MPACK_METRIC_CPU_clob CLOB
VAR MPACK_HOST_clob CLOB
VAR MPACK_SGA_PGA_METRIC_clob CLOB
VAR MPACK_DBSIZE_clob CLOB
VAR MPACK_DAILY_ARCH_METRIC_clob CLOB
VAR MPACK_QUERIES_clob CLOB
VAR MPACK_METRIC_clob CLOB
VAR MPACK_BLOCKSIZE_clob CLOB

DECLARE
    --
    table_does_not_exist EXCEPTION;
    PRAGMA EXCEPTION_INIT(table_does_not_exist, -942); 
    --
    --declate a type to hold summary rows
    TYPE t_summary
        IS TABLE OF integer 
        INDEX BY VARCHAR2(50);
    --
    v_column_sep CHAR(1):= '|';
    v_nv_sep    CHAR(1) := ':';
    v_field_sep CHAR(1) := ',';
    v_quote     CHAR(1) := '"';
    v_eol       CHAR(1) := chr(10);
    v_open_p    CHAR(1) := '{';
    v_close_p   CHAR(1) := '}';
    v_error_message VARCHAR2(512);
    --
    v_placeholder   VARCHAR2(80)    := '|GUIDPLACEHOLDER|';
    v_extract_dt    VARCHAR2(20)    := to_char(sysdate,'DD-MON-YYYY hh24:mi:ss');
    --
    v_dbinfo          varchar2(32767);
    --
    v_dbid            number;
    v_dbname          varchar2(50);
    v_con_dbid        number;
    v_pdb_con_id      number;
    v_con_dbname      varchar2(30);
    v_pluggable_count number;
    v_unique_dbname   varchar2(30);
    v_resetlogs_scn   number;
    v_instance_number number;
    v_instance_name   varchar2(16);
    v_instance_role   varchar2(18);
    v_hostname        varchar2(64);
    v_exadata_flag    varchar2(1);
    v_gg_flag         varchar2(10);
    v_host_list       varchar2(400);
    v_pdb_host_list   varchar2(400);
    v_version         varchar2(50);
    v_version_major   NUMBER;
    v_version_minor   NUMBER;
    v_multitenant     varchar2(50);
    v_cur_id          VARCHAR2(10);
    --
    -- summary table (associative array)
    v_summary t_summary;
    --
    FUNCTION quote(v_string VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        return v_quote||v_string||v_quote;
    END quote;
    --
    FUNCTION nv_pair(v_name VARCHAR2,v_value VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        return quote(v_name)||v_nv_sep||quote(v_value);
    END nv_pair;
    --
    FUNCTION if_gt_one(p_int INTEGER) RETURN VARCHAR2
    IS
    BEGIN
        IF p_int > 1
        THEN
            return v_field_sep;
        ELSE
            return NULL;
        END IF;
    END if_gt_one;
    --
    PROCEDURE build_summary
    IS
        l_name VARCHAR2(50) := v_summary.FIRST;    
        l_json VARCHAR2(32767) :=   
            'MPACK_SUMMARY'||'|GUIDPLACEHOLDER|'||
            v_dbid||'|'||v_extract_dt||'|'||'0|'||'{';
    --    
    BEGIN
        WHILE l_name IS NOT NULL
        LOOP
            l_json := l_json ||'"'||l_name||'":"'||v_summary(l_name)||'",';
            l_name := v_summary.NEXT(l_name);
        END LOOP;
        l_json := l_json ||'}';
        --
        dbms_lob.writeappend(:mpack_summary_clob, length(l_json), l_json); 
        --
    END build_summary;
    /*
    This procedure is designed to hide the complexity of identifying the
    database that we are connecting to. For 11g, we always want the standard
    database id and name. However, for 12c onwards, we want the standard name
    for non-multitenant, but we want the PDB details if connected to a PDB. We
    use dynamic SQL as the multitenant views do not exist in 11g, so we cannot
    use a comple time parsed cursor.
    */
    PROCEDURE get_database_identifiers(
        p_dbid            OUT NUMBER,    -- This holds the dbid info of the database connection (pluggable dbid if connected to a pluggable)
        p_dbname          OUT VARCHAR2,  -- This holds the database name info of the database connection (pluggable database name if connected to a pluggable)
        p_con_dbid        OUT NUMBER,    -- This holds the dbid of the container database if connected to a pluggable or a container database (if connected to container it has the same value as p_dbid)
                                         -- If connected to a nonCDB (versions 12.x-19.x) then then it takes value 0 
                                         -- if connected to a version below 12 where containers where not applicable it takes value -1
        p_pdb_con_id      OUT NUMBER,    -- if connected to pluggable database it holds the connection id (con_id) of the pluggable database
                                         -- if connected to the container database it holds the value (con_id) of the container database which is always 1
                                         -- if connected connected to a nonCDB (versions 12.x-19.x) then then it takes value 0  which is the value of con_id for all nonCDB databases
                                         -- if connected to a version below 12 where containers where not applicable it takes value -1
        p_con_dbname      OUT VARCHAR2,  -- if connected to pluggable database it holds the database name of the container database
                                         -- if connected to a container database it still holds the database name of the container database but also has the same value as p_dbname
                                         -- if connected to a nonCDB it holds the value of "N/A"
                                         -- if connected to a version below 12 where containers where not applicable it takes value "N/A"
        p_pluggable_count OUT NUMBER,    -- If on CDB count of pluggable databases
        p_unique_dbname   OUT VARCHAR2,  -- it holds the value of the unique database name from v$database
        p_resetlogs_scn   OUT NUMBER,    -- it holds the value of the reset_logs of the database to distinguish between different copies of the same database (prod/test/dev)
        p_instance_number OUT NUMBER,    -- it holds the information of the instance number that the information was collected from 
        p_instance_name   OUT VARCHAR2,  -- it holds the information of the instance name that the information was collected from 
        p_instance_role   OUT VARCHAR2,  -- it holds information about the role instance (e.g. PRIMARY INSTANCE)
        p_hostname        OUT VARCHAR2,  -- it holds information about the host (from v$instance) that information was collected from
        p_exadata_flag    OUT VARCHAR2,  -- it hold information if the host is an Exadata
        p_gg_flag         OUT VARCHAR2,  -- checks if Golden Gate is used or configured
        p_host_list       OUT VARCHAR2,  -- if database uses RAC this is the list of all the hosts of the Cluster
        p_pdb_host_list   OUT VARCHAR2,  -- if a database is PDB list the hosts that it is running when on RAC cluster 
        p_version         OUT VARCHAR,   -- Version of the database (full) as character
        p_version_major   OUT NUMBER,    -- Major Version of the database (first number before the first dot)
        p_version_minor   OUT NUMBER,    -- Minor Version of the database (second number after the first dot before the second)
        p_multitenant     OUT VARCHAR2   -- it hold information if a database is "PDB"/"CDB"/"NonCDB"/"N/A"
    )
    IS
        --
        lv_multitenant_sql varchar2(1024):='select decode(sys_context(''USERENV'', ''CON_NAME''),''CDB$ROOT'',sys_context(''USERENV'', ''DB_NAME''),sys_context(''USERENV'', ''CON_NAME'')) DB_NAME, 
                                                  sys_context(''USERENV'', ''CON_ID'') DB_CON_ID, 
                                                  decode(CDB,''NO'',''nonCDB'',decode(sys_context(''USERENV'',''CON_ID''),1,''CDB'',''PDB'')) DBTYPE, 
                                                  name CDB_DB_NAME,
                                                  DB_UNIQUE_NAME,
                                                  DBID CON_DBID,
                                                  sys_context(''USERENV'', ''CON_DBID'') PDB_DBID,
                                                  RESETLOGS_CHANGE# RESETLOGS_SCN
                                           from   v$database';
        lv_pdb_count_sql   varchar2(500):='SELECT (count(*)-1) pdb_count FROM v$PDBS';
        lv_exa_flag_10g    varchar2(500):='select count(*) from v$system_event a, v$event_name b where a.event_id=b.event_id and b.name=''cell single block physical read''';
        lv_exa_flag        varchar2(500):='select count(*) from (select distinct cell_name from gv$cell_state)';
        lv_host_list       varchar2(1024):='select listagg( HOST_NAME, '','') 
                                                   within group (order by HOST_NAME) "HOST_LIST" 
                                                          from ( select CASE INSTR( HOST_NAME, ''.'', 1 ) 
                                                                        when 0 then HOST_NAME 
                                                                        ELSE SUBSTR( HOST_NAME, 1,  INSTR( HOST_NAME, ''.'', 1 )-1 ) end HOST_NAME 
                                              from gv$instance )';
        lv_pdb_host_list   varchar2(1024):='select listagg( HOST_NAME, '','') 
                                                   within group (order by HOST_NAME) "HOST_LIST" 
                                                          from ( select CASE INSTR( a.HOST_NAME, ''.'', 1 ) 
                                                                        when 0 then a.HOST_NAME 
                                                                        ELSE SUBSTR( a.HOST_NAME, 1,  INSTR( a.HOST_NAME, ''.'', 1 )-1 ) end HOST_NAME 
                                              from gv$instance a, 
                                                   gv$pdbs b 
                                             where a.inst_id = b.inst_id 
                                               and b.con_id = sys_context(''USERENV'',''CON_ID'') 
                                               and open_mode =''READ WRITE'')';
        lv_host_list_10g   varchar2(4000):='select host1 || case when host2 is not null then '','' || host2 end
                                                         || case when host3 is not null then '','' || host3 end
                                                         || case when host4 is not null then '','' || host4 end
                                                         || case when host5 is not null then '','' || host5 end 
                                                         || case when host6 is not null then '','' || host6 end 
                                                         || case when host7 is not null then '','' || host7 end 
                                                         || case when host8 is not null then '','' || host8 end "HOST_LIST"
                                            from ( SELECT MAX( CASE WHEN inst_id = 1 THEN host_name END) host1,
                                                          MAX( CASE WHEN inst_id = 2 THEN host_name END) host2,
                                                          MAX( CASE WHEN inst_id = 3 THEN host_name END) host3,
                                                          MAX( CASE WHEN inst_id = 4 THEN host_name END) host4,
                                                          MAX( CASE WHEN inst_id = 5 THEN host_name END) host5,
                                                          MAX( CASE WHEN inst_id = 6 THEN host_name END) host6,
                                                          MAX( CASE WHEN inst_id = 7 THEN host_name END) host7,
                                                          MAX( CASE WHEN inst_id = 8 THEN host_name END) host8
                                                    FROM ( select inst_id, 
                                                                  CASE WHEN INSTR( host_name, ''.'', 1 )=0 THEN host_name
                                                                       ELSE substr( host_name, 1, INSTR( host_name, ''.'', 1 )-1 )
                                                                  END host_name
                                                             from gv$instance ))';

        lv_gg_integrated   varchar2(512):= 'select decode(value,''FALSE'',0,1) GG_COUNT from v$parameter where name=''enable_goldengate_replication''';
        lv_gg_classic      varchar2(512):= 'select count(*) from dba_hist_active_sess_history where program like ''extract@%''';
        --
        lv_cursor SYS_REFCURSOR;
        --
        l_exa_flag  number:=0;
        l_gg_flag   number:=0;
        l_pdb_count number;

    BEGIN
    -- Get the basic basic identifiers that exist for all verisons of database
    -- from 11g onwards
        
    -- First select Version of the database including minor number 
        SELECT version,
               to_number(substr(version,1,instr(version,'.',1,1)-1)) version_number_major,
               to_number(substr(version,instr(version,'.')+1,instr(version,'.',1,2)-instr(version,'.')-1)) version_number_minor
          INTO p_version, p_version_major, p_version_minor
          from dba_registry
         where comp_id='CATPROC';

        -- Populate information about the instance and host the information was queried from 
        --
        SELECT INSTANCE_NUMBER,   INSTANCE_NAME,   HOST_NAME,  INSTANCE_ROLE
          INTO p_instance_number, p_instance_name, p_hostname, p_instance_role
          FROM V$INSTANCE;
        -- populate Identifiers based on version of multitenant 
        -- if version (major) of the database is before 12 and after 9 then there is no multitenant option hence 
        -- p_con_dbname will be set to N/A p_con_dbid to 0
        if p_version_major > 11 then
           open lv_cursor for lv_multitenant_sql;
           fetch lv_cursor into p_dbname, p_pdb_con_id, p_multitenant, p_con_dbname, p_unique_dbname, p_con_dbid, p_dbid, p_resetlogs_scn;
           close lv_cursor;
           if p_multitenant = 'CDB' then
              open lv_cursor for lv_pdb_count_sql;
              fetch lv_cursor into p_pluggable_count;
              close lv_cursor;
           else
              p_pluggable_count:=-1;
           end if;
           if p_multitenant = 'PDB' then
              open lv_cursor for lv_pdb_host_list;
              fetch lv_cursor into p_pdb_host_list;
              close lv_cursor;
           else
              p_pdb_host_list := 'N/A';
           end if;
        else 
           SELECT DBID,   NAME,     RESETLOGS_CHANGE#, DB_UNIQUE_NAME
             INTO p_dbid, p_dbname, p_resetlogs_scn,   p_unique_dbname
             FROM v$database;
             p_pdb_con_id      := -1;
             p_multitenant     := 'N/A';
             p_con_dbname      := 'N/A';
             p_con_dbid        := -1;
             p_pluggable_count := -1;
             p_pdb_host_list   := 'N/A';
        end if;
        --
        -- Gets all database identifiers for all versions and populate the following values
        -- p_exa_flag, p_multitenant, p_con_dbname, p_con_dbid, p_pdb_con_id
        -- populate the host list, the host list provides all the hostnames that a database cluster is using (on RAC many on non-RAC just one)
        -- make necessary changes to p_dbname, p_dbid if connected to a pluggable
        --
        -- Exadata or not
        -- 1. From version 11gR2 view gv$cell_state allows you to view information of the number of Exadata CELLS in a database and hence identifies Exadata
        -- 2. For versions below we query the existence of the event "cell single block physical read" which can only exist if database runs on Exadata
        -- Host List
        -- 1. Also from version 11gR2 LISTAGG is a function which orders data within each group specified in the ORDER BY clause this is used to produce 
        --    the list of hostnames fromgv$instance
        -- 2. For lesser versions we run a CASE query the number of hostnames to 8 (so Exadata databases can be captured and highly unlikely to have more than 8 outside Exadata)
        --

        if to_number(to_char(p_version_major)||'.'||to_char(p_version_minor)) > 11.1 then
           -- Checks for Exa
           open lv_cursor for lv_exa_flag;
           fetch lv_cursor into l_exa_flag;
           close lv_cursor;
           -- Populates Hostnames of database in the cluster (RAC)
           open lv_cursor for lv_host_list;
           fetch lv_cursor into p_host_list;
           close lv_cursor;
        else
           -- Checks for Exa
           open lv_cursor for lv_exa_flag_10g;
           fetch lv_cursor into l_exa_flag;
           close lv_cursor;
           -- Populates Hostnames of database in the cluster (RAC)
           open lv_cursor for lv_host_list_10g;
           fetch lv_cursor into p_host_list;
           close lv_cursor;
        end if;
        
        if l_exa_flag >0 then
           p_exadata_flag:='Y';
        else
           p_exadata_flag:='N';
        end if;

        open lv_cursor for lv_gg_integrated;
        fetch lv_cursor into l_gg_flag;
        close lv_cursor;

        if l_gg_flag = 1 then
           p_gg_flag := 'INTEGRATED';
        else
           open lv_cursor for lv_gg_classic;
           fetch lv_cursor into l_gg_flag;
           close lv_cursor;

           if l_gg_flag > 0 then
              p_gg_flag:='CLASSIC';
           else
              p_gg_flag:='N/A';
           end if;
        end if;

    END get_database_identifiers;
    --
    --    
    --
        /*
    The get_cursor function returns a open cursor for a specific sql id.
    By putting all the sql needed into a single call, we can use standard
    error checking and logging. 
    */
    FUNCTION get_cursor (
        p_cur_name VARCHAR2
    )
    RETURN varchar2 --sys_refcursor 
    IS
        --v_cur   sys_refcursor;
        v_cur_stmt varchar2(32000);
    BEGIN
        IF p_cur_name = 'dummy' THEN
            --OPEN v_cur FOR 'SELECT DBID, NAME from v$database';
        v_cur_stmt:='SELECT DBID, NAME from v$database';

/*****MPACK_TRANSACTIONS*****/
        ELSIF p_cur_name = 'MPACK_TRANSACTIONS' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_transactions IS
      
           IF v_multitenant in ('N/A','nonCDB','CDB') THEN 
              --  OPEN v_cur FOR
              v_cur_stmt:=
'

-- version_required : All versions except PDBs

SELECT 
       st.dbid,
       st.snap_id,
       st.instance_number,
       decode('||v_version_major||',10,-1,11,-1,st.dbid) con_db_id,
       datetime,
       ROUND (SUM (delta_value) / 3600, 2) "Transactions per second"
  FROM (SELECT dbid, 
               instance_number,
               snap_id,
               round(begin_interval_time,''MI'') datetime,
               (begin_interval_time + 0 - LAG (begin_interval_time + 0)
          OVER (PARTITION BY dbid, instance_number ORDER BY snap_id)) * 86400 diff_time
          FROM dba_hist_snapshot) sn, 
       (SELECT dbid,
               instance_number,
               snap_id,
               stat_name,
               VALUE - LAG (VALUE) 
          OVER (PARTITION BY dbid,instance_number,stat_name ORDER BY snap_id) delta_value
          FROM dba_hist_sysstat
         WHERE stat_name IN (''user commits'', ''user rollbacks'')) st
 WHERE st.instance_number = sn.instance_number
   AND st.snap_id = sn.snap_id
   AND diff_time IS NOT NULL
 GROUP BY datetime, st.snap_id, st.dbid, st.instance_number
 ORDER BY datetime desc


';

           ELSIF  v_multitenant = 'PDB' THEN
              IF  to_number(to_char(v_version_major)||'.'||to_char(v_version_minor)) > 12.1  THEN
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
q'[

-- version_required : 12.0

SELECT 
       st.dbid,
       st.snap_id,
       st.instance_number,
       st.con_dbid,
       datetime,
       ROUND (SUM (delta_value) / 3600, 2) "Transactions per second"
  FROM (SELECT dbid, 
               instance_number,
               snap_id,
               round(begin_interval_time,'MI') datetime,
               (begin_interval_time + 0 - LAG (begin_interval_time + 0)
          OVER (PARTITION BY dbid, instance_number ORDER BY snap_id)) * 86400 diff_time
          FROM dba_hist_snapshot) sn, 
       (SELECT dbid,
               instance_number,
               con_dbid,
               snap_id,
               stat_name,
               VALUE - LAG (VALUE) 
          OVER (PARTITION BY dbid,instance_number,stat_name ORDER BY snap_id) delta_value
          FROM dba_hist_con_sysstat 
         WHERE stat_name IN ('user commits', 'user rollbacks')) st
 WHERE st.instance_number = sn.instance_number
   AND st.snap_id = sn.snap_id
   AND diff_time IS NOT NULL
 GROUP BY datetime, st.snap_id, st.dbid, st.instance_number, con_dbid
 ORDER BY datetime desc

]';
              ELSE
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
'

-- specific for PDBs in version 12.1§

SELECT 
       st.dbid,
       st.snap_id,
       st.instance_number,
       decode('||v_version_major||',10,-1,11,-1,st.dbid) con_db_id,
       datetime,
       ROUND (SUM (delta_value) / 3600, 2)/'||v_pluggable_count||' "Transactions per second"
  FROM (SELECT dbid, 
               instance_number,
               snap_id,
               round(begin_interval_time,''MI'') datetime,
               (begin_interval_time + 0 - LAG (begin_interval_time + 0)
          OVER (PARTITION BY dbid, instance_number ORDER BY snap_id)) * 86400 diff_time
          FROM dba_hist_snapshot) sn, 
       (SELECT dbid,
               instance_number,
               snap_id,
               stat_name,
               VALUE - LAG (VALUE) 
          OVER (PARTITION BY dbid,instance_number,stat_name ORDER BY snap_id) delta_value
          FROM dba_hist_sysstat
         WHERE stat_name IN (''user commits'', ''user rollbacks'')) st
 WHERE st.instance_number = sn.instance_number
   AND st.snap_id = sn.snap_id
   AND diff_time IS NOT NULL
 GROUP BY datetime, st.snap_id, st.dbid, st.instance_number
 ORDER BY datetime desc

';
             END IF;
         

           END IF;


/*****MPACK_USERSCONNECTED*****/
        ELSIF p_cur_name = 'MPACK_USERSCONNECTED' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_usersconnected IS

           IF v_multitenant = 'PDB' THEN 
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[

-- db_type required : PDB

with x as
   (select distinct
           sid,
           serial#,
           osuser,
           authentication_type,
           inst_id,
           client_connection,
           client_oci_library,
           client_version,
           client_driver
     from  gv$session_connect_info)
SELECT * from 
(select sys_context('USERENV', 'CON_DBID') DBID
          from v$database),
(select x.osuser,        
        x.authentication_type,
        y.username, 
        x.inst_id,  
        y.MACHINE, 
        y.PROGRAM,
        y.module,
        x.client_connection,
        x.client_oci_library,
        x.client_version,
        x.client_driver,
        y.terminal,
        count(*) CONNECTIONS
   from x, gv$session y 
  where x.sid = y.sid
    and x.serial#=y.serial#
    and y.type !='BACKGROUND'
  group by x.osuser,        
           x.authentication_type,
           y.username, 
           x.inst_id,  
           y.MACHINE, 
           y.PROGRAM,
           y.module,
           x.client_connection,
           x.client_oci_library,
           x.client_version,
           x.client_driver,
           y.terminal) 


]';

           ELSE
              IF v_version_major > 10 then
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
q'[

-- db_type required : CDB,nonCDB,N/A
-- version required 11+

with x as
   (select distinct
           sid,
           serial#,
           osuser,
           authentication_type,
           inst_id,
           client_connection,
           client_oci_library,
           client_version,
           client_driver
     from  gv$session_connect_info)
SELECT * from 
(select   DBID
          from v$database),
(select x.osuser,        
        x.authentication_type,
        y.username, 
        x.inst_id,  
        y.MACHINE, 
        y.PROGRAM,
        y.module,
        x.client_connection,
        x.client_oci_library,
        x.client_version,
        x.client_driver,
        y.terminal,
        count(*) CONNECTIONS
   from x, gv$session y 
  where x.sid = y.sid
    and x.serial#=y.serial#
    and y.type !='BACKGROUND'
  group by x.osuser,        
           x.authentication_type,
           y.username, 
           x.inst_id,  
           y.MACHINE, 
           y.PROGRAM,
           y.module,
           x.client_connection,
           x.client_oci_library,
           x.client_version,
           x.client_driver,
           y.terminal)
]';
              ELSE
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
q'[

 with x as
   (select distinct
           sid,
           'N/A' serial#,
           osuser,
           authentication_type,
           inst_id,
           'N/A' client_connection,
           'N/A' client_oci_library,
           'N/A' client_version,
           'N/A' client_driver
     from  gv$session_connect_info)
SELECT * from 
(select   DBID
          from v$database),
(select x.osuser,        
        x.authentication_type,
        y.username, 
        x.inst_id,  
        y.MACHINE, 
        y.PROGRAM,
        y.module,
        x.client_connection,
        x.client_oci_library,
        x.client_version,
        x.client_driver,
        y.terminal,
        count(*) CONNECTIONS
   from x, gv$session y 
  where x.sid = y.sid
    and x.inst_id = y.inst_id
    and y.type !='BACKGROUND'
  group by x.osuser,        
           x.authentication_type,
           y.username, 
           x.inst_id,  
           y.MACHINE, 
           y.PROGRAM,
           y.module,
           x.client_connection,
           x.client_oci_library,
           x.client_version,
           x.client_driver,
           y.terminal)
]';

              END IF;

           END IF;

/*****MPACK_METRIC_CPU*****/
        ELSIF p_cur_name = 'MPACK_METRIC_CPU' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_metric_cpu IS

           IF v_multitenant in ('N/A','nonCDB','CDB')  THEN 
              -- OPEN v_cur FOR
              v_cur_id:='CPU1';
              v_cur_stmt:=
q'[

-- version_required : 11.0

SELECT instance_number, 
       first_snap_id, 
       second_snap_id, 
       begin_time, 
       end_time, 
       ROUND(dbtime_mins/(elapsed_mins*num_cpus)*100, 2) || '%' awr_cpu_load
  FROM (SELECT dhsp.instance_number, 
               LAG(dhsp.snap_id, 1, 0) OVER (PARTITION BY dhsp.dbid, dhsp.instance_number ORDER BY dhsp.snap_id) first_snap_id, 
               dhsp.snap_id second_snap_id, 
               CAST(dhsp.begin_interval_time AS DATE) begin_time, 
               CAST(dhsp.end_interval_time AS DATE) end_time, 
               ROUND((dhstm.value - LAG(dhstm.value, 1, 0) OVER (PARTITION BY dhstm.dbid, dhstm.instance_number ORDER BY dhstm.snap_id))/1e6/6e1, 2) dbtime_mins, 
               (CAST(dhsp.end_interval_time AS DATE) - CAST(begin_interval_time AS DATE))*24*6e1 elapsed_mins, 
               dhos.value num_cpus
          FROM (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       begin_interval_time, 
                       end_interval_time
                FROM dba_hist_snapshot
               ) dhsp,
               (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       stat_name, 
                       value
                  FROM dba_hist_sys_time_model
                 WHERE stat_name = 'DB time'
               ) dhstm,
               (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       stat_name, 
                       value
                  FROM dba_hist_osstat
                 WHERE stat_name = 'NUM_CPUS'
               ) dhos
          WHERE dhsp.snap_id = dhstm.snap_id
            AND dhsp.instance_number  = dhstm.instance_number
            AND   dhsp.dbid             = dhstm.dbid
            AND   dhstm.snap_id         = dhos.snap_id
            AND   dhstm.instance_number = dhos.instance_number
            AND   dhstm.dbid            = dhos.dbid
        ORDER BY dhsp.instance_number, 
                 first_snap_id) all_awr_dbtime_and_cpus
 WHERE first_snap_id <> 0


]';

           ELSIF  v_multitenant = 'PDB' THEN 
              IF to_number(to_char(v_version_major)||'.'||to_char(v_version_minor)) > 12.1 THEN 
                 -- OPEN v_cur FOR
                 v_cur_id:='CPU2';
                 v_cur_stmt:=
q'[

-- version_required : 12.0

SELECT instance_number, 
       first_snap_id, 
       second_snap_id, 
       begin_time, 
       end_time, 
       ROUND(dbtime_mins/(elapsed_mins*num_cpus)*100, 2) || '%' awr_cpu_load
  FROM (SELECT dhsp.instance_number, 
               LAG(dhsp.snap_id, 1, 0) OVER (PARTITION BY dhsp.dbid, dhsp.instance_number ORDER BY dhsp.snap_id) first_snap_id, 
               dhsp.snap_id second_snap_id, 
               CAST(dhsp.begin_interval_time AS DATE) begin_time, 
               CAST(dhsp.end_interval_time AS DATE) end_time, 
               ROUND((dhstm.value - LAG(dhstm.value, 1, 0) OVER (PARTITION BY dhstm.dbid, dhstm.instance_number ORDER BY dhstm.snap_id))/1e6/6e1, 2) dbtime_mins, 
               (CAST(dhsp.end_interval_time AS DATE) - CAST(begin_interval_time AS DATE))*24*6e1 elapsed_mins, 
               dhos.value num_cpus
          FROM (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       begin_interval_time, 
                       end_interval_time
                FROM dba_hist_snapshot
               ) dhsp,
               (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       stat_name, 
                       value
                  FROM dba_hist_con_sys_time_model
                 WHERE stat_name = 'DB time'
               ) dhstm,
               (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       stat_name, 
                       value
                  FROM dba_hist_osstat
                 WHERE stat_name = 'NUM_CPUS'
               ) dhos
          WHERE dhsp.snap_id = dhstm.snap_id
            AND dhsp.instance_number  = dhstm.instance_number
            AND   dhsp.dbid             = dhstm.dbid
            AND   dhstm.snap_id         = dhos.snap_id
            AND   dhstm.instance_number = dhos.instance_number
            AND   dhstm.dbid            = dhos.dbid
        ORDER BY dhsp.instance_number, 
                 first_snap_id) all_awr_dbtime_and_cpus
 WHERE first_snap_id <> 0

]';
              ELSE
                 -- OPEN v_cur FOR
                 v_cur_id:='CPU3';
                 v_cur_stmt:=
'
SELECT instance_number, 
       first_snap_id, 
       second_snap_id, 
       begin_time, 
       end_time, 
       ROUND(dbtime_mins/(elapsed_mins*num_cpus)*100, 2)/'||v_pluggable_count||' || ''%'' awr_cpu_load
  FROM (SELECT dhsp.instance_number, 
               LAG(dhsp.snap_id, 1, 0) OVER (PARTITION BY dhsp.dbid, dhsp.instance_number ORDER BY dhsp.snap_id) first_snap_id, 
               dhsp.snap_id second_snap_id, 
               CAST(dhsp.begin_interval_time AS DATE) begin_time, 
               CAST(dhsp.end_interval_time AS DATE) end_time, 
               ROUND((dhstm.value - LAG(dhstm.value, 1, 0) OVER (PARTITION BY dhstm.dbid, dhstm.instance_number ORDER BY dhstm.snap_id))/1e6/6e1, 2) dbtime_mins, 
               (CAST(dhsp.end_interval_time AS DATE) - CAST(begin_interval_time AS DATE))*24*6e1 elapsed_mins, 
               dhos.value num_cpus
          FROM (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       begin_interval_time, 
                       end_interval_time
                FROM dba_hist_snapshot
               ) dhsp,
               (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       stat_name, 
                       value
                  FROM dba_hist_sys_time_model
                 WHERE stat_name = ''DB time''
               ) dhstm,
               (SELECT snap_id, 
                       dbid, 
                       instance_number, 
                       stat_name, 
                       value
                  FROM dba_hist_osstat
                 WHERE stat_name = ''NUM_CPUS''
               ) dhos
          WHERE dhsp.snap_id = dhstm.snap_id
            AND dhsp.instance_number  = dhstm.instance_number
            AND   dhsp.dbid             = dhstm.dbid
            AND   dhstm.snap_id         = dhos.snap_id
            AND   dhstm.instance_number = dhos.instance_number
            AND   dhstm.dbid            = dhos.dbid
        ORDER BY dhsp.instance_number, 
                 first_snap_id) all_awr_dbtime_and_cpus
 WHERE first_snap_id <> 0
';
              END IF;

           END IF;

/*****MPACK_HOST*****/
        ELSIF p_cur_name = 'MPACK_HOST' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_host IS 
-- All version and CDB/PDB follow the same query
-- IOWAIT_TIME stat does not exist in 10gR2
-- NUM_CPU_CORES stat does not exist in 10gR2, 11gR1, 11gR2
-- NUM_CPU_SOCKETS stat does not exist in 10gR2, 11gR1, 11gR2
-- Metrics Collected here apply to HOST level ONLY
           -- OPEN v_cur FOR
           v_cur_stmt:=

q'[

-- version_required : 11.0

select snap_id,
       dbid,
       instance_number,
       db_name,
       host_name,
       max(decode( stat_name, 'NUM_CPUS'                , value , null ))  as cpus,
       max(decode( stat_name, 'IDLE_TIME'               , value , null ))  as idle,
       max(decode( stat_name, 'BUSY_TIME'               , value , null ))  as busy,
       max(decode( stat_name, 'USER_TIME'               , value , null ))  as  usr,
       max(decode( stat_name, 'SYS_TIME'                , value , null ))  as cpusys,
       max(decode( stat_name, 'IOWAIT_TIME'             , value , null ))  as iowait, 
       max(decode( stat_name, 'NUM_CPU_CORES'           , value , null ))  as cores,
       max(decode( stat_name, 'NUM_CPU_SOCKETS'         , value , null ))  as sockets,
       max(decode( stat_name, 'PHYSICAL_MEMORY_BYTES'   , value , null ))  as ram
  from (select s.snap_id,
               s.dbid, 
               s.instance_number, 
               d.db_name, 
               d.host_name,
               s.stat_name, s.value 
          from DBA_HIST_OSSTAT  s 
               inner join DBA_HIST_OSSTAT n 
                     on s.dbid = n.dbid and s.instance_number = n.instance_number and s.snap_id = n.snap_id
               inner join DBA_HIST_DATABASE_INSTANCE d 
                     on n.dbid = d.dbid and n.instance_number = d.instance_number
       ) 
 group by snap_id,
          dbid,
          instance_number,
          db_name,
          host_name 


]';


/*****MPACK_SGA_PGA_METRIC*****/
        ELSIF p_cur_name = 'MPACK_SGA_PGA_METRIC' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_pga_metric IS

           IF v_multitenant = 'PDB' and to_number(to_char(v_version_major)||'.'||to_char(v_version_minor)) > 12.1 then   
              v_cur_id:='MEM1';    
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[

-- Current PGA Metrics
-- For all versions PDB and CDB
-- For version 12.1 PGA is common between CDB and PDB

select x.DBID,
       s.mbytes total_pga_in_use,
       '' TOTAL_PGA_ALLOCATED,
       (z.mbytes + r.mbytes) sga_bytes,
       z.mbytes buffer_cache_bytes,
       r.mbytes shared_pool_bytes
  from (select sys_context('USERENV', 'CON_DBID') DBID
          from v$database) x, 
       (select max(pga_bytes) mbytes
          from v$rsrcpdbmetric_history) s, 
       (select max(buffer_cache_bytes) mbytes
          from v$rsrcpdbmetric_history) z,
       (select max(shared_pool_bytes) mbytes
          from v$rsrcpdbmetric_history) r

]';
           ELSIF v_multitenant = 'CDB' then
              v_cur_id:='MEM2';
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[

select DBID, TOTAL_PGA_IN_USE, TOTAL_PGA_ALLOCATED, SGA_BYTES, BUFFER_CACHE_BYTES, SHARED_POOL_BYTES
  from (select DBID
          from v$database),
       (select value TOTAL_PGA_IN_USE
          from V$PGASTAT
         where name = 'total PGA inuse') pu,
       (select value TOTAL_PGA_ALLOCATED
          from V$PGASTAT
         where name = 'total PGA allocated') pa,  
       (select round(s.mbytes) SGA_BYTES,
               round(o.mbytes) SHARED_POOL_BYTES,
               round(b.mbytes) BUFFER_CACHE_BYTES
          from (select sum(bytes) mbytes
                  from v$sgastat
                 where con_id in (0,1)) s,
               (select sum(bytes) mbytes
                  from v$sgastat  
                where pool  like '%pool%'
                  and con_id in (0,1)) o,
               (select sum(bytes) mbytes
                  from v$sgastat 
                 where pool is null
                   and con_id in (0,1)) b)

]';
           ELSE
              v_cur_id:='MEM3';
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[

select DBID, TOTAL_PGA_IN_USE, TOTAL_PGA_ALLOCATED, SGA_BYTES, BUFFER_CACHE_BYTES, SHARED_POOL_BYTES
  from (select DBID
          from v$database),
       (select value TOTAL_PGA_IN_USE
          from V$PGASTAT
         where name = 'total PGA inuse') pu,
       (select value TOTAL_PGA_ALLOCATED
          from V$PGASTAT
         where name = 'total PGA allocated') pa,  
       (select round(s.mbytes) SGA_BYTES,
               round(o.mbytes) SHARED_POOL_BYTES,
               round(b.mbytes) BUFFER_CACHE_BYTES
          from (select sum(bytes) mbytes
                  from v$sgastat) s,
               (select sum(bytes) mbytes
                  from v$sgastat  
                where pool  like '%pool%') o,
               (select sum(bytes) mbytes
                  from v$sgastat 
                 where pool is null) b)
]';
           END IF;


/*****MPACK_DBSIZE*****/
        ELSIF p_cur_name = 'MPACK_DBSIZE' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_dbsize IS
           -- OPEN v_cur FOR
           v_cur_stmt:=

q'[

-- version_required : 11.0

select round(sum(used_ts_size)/1024, 2) TOTAL_USED_DB_SIZE_GB,
       round(sum(curr_ts_size)/1024, 2) TOTAL_CURRENT_DB_SIZE_GB,
       round(sum(max_ts_size)/1024, 2) TOTAL_MAX_ALLOCATED_DB_SIZE_GB
  from (select /*+ leading(df) use_nl(fs) opt_param('_optimizer_sortmerge_join_enabled','false') */ df.tablespace_name, (df.bytes - sum(fs.bytes)) / (1024 * 1024) used_ts_size,
               df.bytes / (1024 * 1024) curr_ts_size,
               df.maxbytes / (1024 * 1024) max_ts_size
          from dba_free_space fs,
               (select tablespace_name,
                       sum(bytes) bytes,
                       sum(decode(maxbytes, 0, bytes, maxbytes)) maxbytes
                  from dba_data_files
                 group by tablespace_name) df
         where fs.tablespace_name (+) = df.tablespace_name
         group by df.tablespace_name,df.bytes,df.maxbytes )


]';

/*****MPACK_DAILY_ARCH_METRIC*****/
        ELSIF p_cur_name = 'MPACK_DAILY_ARCH_METRIC' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_sga_metric IS

           IF v_multitenant = 'CDB'  THEN 
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[

-- version_required : 11.0

select y.dbid,
       x.ARCH_DAILY_GB TOTAL_DAILY_ARCHIVE,
       (s.redo_size/t.total_redo)*x.ARCH_DAILY_GB DB_DAILY_ARCHIVE_EST,
       s.con_id
  from (select max(GB) ARCH_DAILY_GB
          from (select trunc(COMPLETION_TIME,'DD') Day, thread#, 
                       round(sum(BLOCKS*BLOCK_SIZE)/1024/1024/1024) GB,
                       count(*) Archives_Generated 
                  from gv$archived_log
                 group by trunc(COMPLETION_TIME,'DD'),thread# order by 1)) x,
       (select dbid
          from v$database) y,
       (select value redo_size,
               con_id
          from v$con_sysstat
          where name='redo size') s,
       (select sum(value) total_redo
          from v$con_sysstat
         where name='redo size') t


]';

           ELSIF  v_multitenant = 'PDB'  THEN 
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[
select y.dbid,
       x.ARCH_DAILY_GB TOTAL_DAILY_ARCHIVE,
       (s.redo_size/t.total_redo)*x.ARCH_DAILY_GB DB_DAILY_ARCHIVE_EST,
       s.con_id
  from (select max(GB) ARCH_DAILY_GB
          from (select trunc(COMPLETION_TIME,'DD') Day, thread#, 
                       round(sum(BLOCKS*BLOCK_SIZE)/1024/1024/1024) GB,
                       count(*) Archives_Generated 
                  from gv$archived_log
                 group by trunc(COMPLETION_TIME,'DD'),thread# order by 1)) x,
       (select dbid
          from v$database) y,
       (select value redo_size,
                '' con_id
          from v$sysstat
         where name='redo size') s,
       (select sum(value) total_redo
          from v$sysstat
          where name='redo size') t
]';

           ELSE 
              -- OPEN v_cur FOR
              v_cur_stmt:=
q'[
select y.dbid,
       x.ARCH_DAILY_GB TOTAL_DAILY_ARCHIVE,
       '' DB_DAILY_ARCHIVE_EST,
       '' CON_ID
  from (select max(GB) ARCH_DAILY_GB
          from (select trunc(COMPLETION_TIME,'DD') Day, thread#, 
                       round(sum(BLOCKS*BLOCK_SIZE)/1024/1024/1024) GB,
                       count(*) Archives_Generated 
                  from gv$archived_log
                 group by trunc(COMPLETION_TIME,'DD'),thread# order by 1)) x,
       (select DBID
          from v$database) y
]';
 
           END IF;


/*****MPACK_QUERIES*****/
     ELSIF p_cur_name = 'MPACK_QUERIES' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- more columns to be added - to see how much is on cpu (performance) 
-- the sql text, not only sql id
-- CURSOR c_queries IS

      IF to_number(to_char(v_version_major)||'.'||to_char(v_version_minor)) > 11.1 THEN 
         -- OPEN v_cur FOR
         v_cur_stmt:=
q'[

select * from (select sa.sql_id,
                      sp.child_number,
                      sp.plan_hash_value,
                      sa.parsing_schema_name SQL_PARSED_BY,
                      sa.module,
                      sa.action,
                      sa.buffer_gets,
                      sa.BG_PER_EXEC,
                      sp.object_owner, --sp.object_name, -- this is the group factor
                      sa.optimizer_cost,
                      sp.cost COST_PER_EXP_OBJECT,
                      round((sp.cost/sa.optimizer_cost)*100,0) OBJECT_COST_RELATION,
                      listagg(OBJECT_NAME,', ') within group (order by object_name) MOST_EXPENSIVE_OBJECTS,]'
                      ||'REPLACE(REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(sa.sql_text, ''[|/\\]'', ''*''),''"'', '' ''), CHR(10) || ''|'' || CHR(9), '' ''),''>'',''%gt;''),''<'',''%lt;'') AS sql_text'
||q'[                from (select sql_id,
                              child_number,
                              parsing_schema_name,
                              module,action,
                              buffer_gets,
                              round(buffer_gets/nullif(executions,0),0) BG_PER_EXEC,
                              optimizer_cost,
                              sql_text
                         from v$sql
                        where parsing_schema_name not in ('SYS','SYSTEM', 'RMAN','SYSMAN', 'DBSNMP')
                          and parsing_schema_name not like 'APEX%') sa,
                      (select sql_id, 
                              child_number, 
                              plan_hash_value, 
                              object_owner, 
                              object_name,
                              cost,
                              rank() over (partition by sql_id,child_number order by cost desc nulls last) costrank
                              -- result set partitioned by sql and child to avoid duplicates 
                              -- when same sql is executed by multiple users
                         from v$sql_plan
                        where (operation like '%INDEX%' or operation like '%TABLE%' or operation like '%MAT%')
                             --and options='FULL' -- would limit to full table scans / full object scans
                          and object_owner <>'SYS') sp
                        where sa.sql_id=sp.sql_id
                          and sa.child_number=sp.child_number
                          and costrank=1 -- only use top costly object of each partition
                        group by sa.sql_id,
                                 sp.child_number,
                                 sp.plan_hash_value,
                                 sa.parsing_schema_name,
                                 sa.module,
                                 sa.action,
                                 sa.buffer_gets,
                                 sa.BG_PER_EXEC,
                                 sp.object_owner,
                                 --sp.object_name, -- this is the group factor
                                 sa.optimizer_cost,
                                 sp.cost,
                                 round((sp.cost/sa.optimizer_cost)*100,0),
                                 sa.sql_text
                           order by BG_PER_EXEC desc nulls last)
 where rownum <11

]';

    ELSE 
       -- OPEN v_cur FOR
       v_cur_stmt:=
q'[

-- version_required : 12.0

SELECT * FROM (
    SELECT sa.sql_id,
           sp.child_number,
           sp.plan_hash_value,
           sa.parsing_schema_name AS SQL_PARSED_BY,
           sa.module,
           sa.action,
           sa.buffer_gets,
           sa.BG_PER_EXEC,
           sp.object_owner, --sp.object_name, -- this is the group factor
           sa.optimizer_cost,
           sp.cost AS COST_PER_EXP_OBJECT,
           ROUND((sp.cost / sa.optimizer_cost) * 100, 0) AS OBJECT_COST_RELATION,]'
          ||'REPLACE(REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(REGEXP_REPLACE(sa.sql_text, ''[|/\\]'', ''*''),''"'', '' ''), CHR(10) || ''|'' || CHR(9), '' ''),''>'',''%gt;''),''<'',''%lt;'') AS sql_text'
||q'[ FROM (
        SELECT sql_id,
               child_number,
               parsing_schema_name,
               module,
               action,
               buffer_gets,
               ROUND(buffer_gets / NULLIF(executions, 0), 0) AS BG_PER_EXEC,
               optimizer_cost,
               sql_text
        FROM v$sql
        WHERE parsing_schema_name NOT IN ('SYS', 'SYSTEM', 'RMAN', 'SYSMAN', 'DBSNMP')
          AND parsing_schema_name NOT LIKE 'APEX%'
    ) sa
    JOIN (
        SELECT sql_id,
               child_number,
               plan_hash_value,
               object_owner,
               object_name,
               cost,
               RANK() OVER (PARTITION BY sql_id, child_number ORDER BY cost DESC NULLS LAST) AS costrank
        FROM v$sql_plan
        WHERE (operation LIKE '%INDEX%' OR operation LIKE '%TABLE%' OR operation LIKE '%MAT%')
          AND object_owner <> 'SYS'
    ) sp
    ON sa.sql_id = sp.sql_id
    AND sa.child_number = sp.child_number
    WHERE costrank = 1
    GROUP BY sa.sql_id,
             sp.child_number,
             sp.plan_hash_value,
             sa.parsing_schema_name,
             sa.module,
             sa.action,
             sa.buffer_gets,
             sa.BG_PER_EXEC,
             sp.object_owner,
             sa.optimizer_cost,
             sp.cost,
             ROUND((sp.cost / sa.optimizer_cost) * 100, 0),
             sa.sql_text
    ORDER BY BG_PER_EXEC DESC NULLS LAST
) WHERE rownum < 11

]';

 END IF;



/*****MPACK_METRIC*****/
        ELSIF p_cur_name = 'MPACK_METRIC' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_metric IS

           IF v_multitenant = 'PDB'  THEN 
              IF to_number(to_char(v_version_major)||'.'||to_char(v_version_minor)) > 12.1 then           
                 -- OPEN v_cur FOR
                 v_cur_stmt:=

q'[

-- version_required : 11.0

Select * from (
    select 
        sys_context('USERENV', 'CON_DBID') DBID,
        hs.snap_id,
        hs.begin_time,
        hs.metric_name,
        hs.maxval metric_max,
        hs.average metric_average
    from
        v$database db
    INNER JOIN dba_hist_con_sysmetric_summ hs using (dbid)
    where 
        hs.begin_time > sysdate - 31
        and metric_id in ('18000', '18014', '18020', '18022','18027','18025')
)
PIVOT (
        sum(metric_average) as avg,
        sum(metric_max) as max
        for (metric_name)
        in (
            'Session Count' as sessions,
            'Redo Generated Per Sec' as redo,
            'Physical Reads Per Sec' as reads,
            'Physical Writes Per Sec' as writes,
            'Physical Read Total Bytes Per Sec' as total_reads_bytes,
            'Physical Write Total Bytes Per Sec' as total_writes_bytes
        )
    )
order by 1,2,3

]';         
              ELSE 
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
'

Select * from (
    select 
        sys_context(''USERENV'', ''CON_DBID'') DBID,
        hs.snap_id,
        hs.begin_time,
        hs.metric_name,
        hs.maxval/'||v_pluggable_count||' metric_max,
        hs.average/'||v_pluggable_count||' metric_average
    from
        v$database db
    INNER JOIN dba_hist_sysmetric_summary hs using (dbid)
    where 
        hs.begin_time > sysdate - 31
        and metric_id in (''2143'', ''2016'', ''2092'', ''2100'',''2093'',''2124'')
)
PIVOT (
        sum(metric_average) as avg,
        sum(metric_max) as max
        for (metric_name)
        in (
            ''Session Count'' as sessions,
            ''Redo Generated Per Sec'' as redo,
            ''Physical Read Total IO Requests Per Sec'' as reads,
            ''Physical Write Total IO Requests Per Sec'' as writes,
            ''Physical Read Total Bytes Per Sec'' as total_reads_bytes,
            ''Physical Write Total Per Sec'' as total_writes_bytes
        )
    )
order by 1,2,3

'; 
              END IF;

           ELSE
              IF v_version_major > 10 then            
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
q'[

-- version_required : 12.0

Select * from (
    select 
        dbid,
        hs.snap_id,
        hs.begin_time,
        hs.metric_name,
        hs.maxval metric_max,
        hs.average metric_average
    from
        v$database db
    INNER JOIN dba_hist_sysmetric_summary hs using (dbid)
    where 
        hs.begin_time > sysdate - 31
        and metric_id in ('2143', '2016', '2092', '2100','2093','2124')
)
PIVOT (
        sum(metric_average) as avg,
        sum(metric_max) as max
        for (metric_name)
        in (
            'Session Count' as sessions,
            'Redo Generated Per Sec' as redo,
            'Physical Read Total IO Requests Per Sec' as reads,
            'Physical Write Total IO Requests Per Sec' as writes,
            'Physical Read Total Bytes Per Sec' as total_reads_bytes,
            'Physical Write Total Per Sec' as total_writes_bytes
        )
    )
order by 1,2,3

]';
              ELSE
                 -- OPEN v_cur FOR
                 v_cur_stmt:=
q'[

SELECT 
    dbid,
    snap_id,
    begin_time,
    SUM(CASE WHEN metric_name = 'Session Count' THEN metric_average END) AS sessions_avg,
    MAX(CASE WHEN metric_name = 'Session Count' THEN metric_max END) AS sessions_max,
    SUM(CASE WHEN metric_name = 'Redo Generated Per Sec' THEN metric_average END) AS redo_avg,
    MAX(CASE WHEN metric_name = 'Redo Generated Per Sec' THEN metric_max END) AS redo_max,
    SUM(CASE WHEN metric_name = 'Physical Read Total IO Requests Per Sec' THEN metric_average END) AS reads_avg,
    MAX(CASE WHEN metric_name = 'Physical Read Total IO Requests Per Sec' THEN metric_max END) AS reads_max,
    SUM(CASE WHEN metric_name = 'Physical Write Total IO Requests Per Sec' THEN metric_average END) AS writes_avg,
    MAX(CASE WHEN metric_name = 'Physical Write Total IO Requests Per Sec' THEN metric_max END) AS writes_max,
    SUM(CASE WHEN metric_name = 'Physical Read Total Bytes Per Sec' THEN metric_average END) AS total_reads_bytes_avg,
    MAX(CASE WHEN metric_name = 'Physical Read Total Bytes Per Sec' THEN metric_max END) AS total_reads_bytes_max,
    SUM(CASE WHEN metric_name = 'Physical Write Total Per Sec' THEN metric_average END) AS total_writes_bytes_avg,
    MAX(CASE WHEN metric_name = 'Physical Write Total Per Sec' THEN metric_max END) AS total_writes_bytes_max
FROM (
    SELECT 
        db.dbid,
        hs.snap_id,
        hs.begin_time,
        hs.metric_name,
        hs.maxval AS metric_max,
        hs.average AS metric_average
    FROM
        v$database db
    INNER JOIN dba_hist_sysmetric_summary hs ON db.dbid = hs.dbid
    WHERE 
        hs.begin_time > sysdate - 31
        AND metric_id IN ('2143', '2016', '2092', '2100','2093','2124')
) metrics
GROUP BY dbid, snap_id, begin_time
ORDER BY dbid, snap_id, begin_time

]';
              END IF;
           END IF;

/*****MPACK_BLOCKSIZE*****/
        ELSIF p_cur_name = 'MPACK_BLOCKSIZE' THEN 
-- CPAT Cursor to check for the use of rowid's in column definitions
-- CURSOR c_blocksize IS

           -- OPEN v_cur FOR
           v_cur_stmt:=
q'[

-- version_required : 11.0

select db.dbid, db.name, dp.name, dp.value from 
v$database db, v$parameter dp where dp.name in ('db_block_size')


]';


        END IF;
        RETURN v_cur_stmt; --v_cur;
    END get_cursor;
    --
    PROCEDURE build_row(
        p_cur_name VARCHAR2,
        p_version_major NUMBER,
        p_version_minor NUMBER,
        p_multitenant VARCHAR2,
        p_con_dbid NUMBER,
        p_pluggable_count NUMBER,
        p_version_required NUMBER,
        p_clob IN OUT CLOB
        )
    IS
        v_cur   SYS_REFCURSOR;
        v_cur_stmt VARCHAR2(32000);
        v_cursor_id     NUMBER;
        v_num_columns    NUMBER;
        v_desc_tab   DBMS_SQL.DESC_TAB;
        --
        v_string VARCHAR2(4000); --changed this to 4000 after test with VF
        v_row_data  VARCHAR2(32198);
        v_row_count INTEGER := 0;
        v_rows_processed integer;
        --
    BEGIN
       -- First check if this cursor requires version 12 or above, if so, check the database version
       IF to_number(to_char(p_version_major)||'.'||to_char(p_version_minor)) < p_version_required THEN
           RETURN;
       END IF;
           
       -- Call the function that returns the referenced cursor
    
           v_cur_stmt := get_cursor(p_cur_name);
       
       -- Switch to native dynamic SQL to get the cursor ID
       v_cursor_id := DBMS_SQL.OPEN_CURSOR;
       BEGIN
       -- PARSE statement and handle execptions
          DBMS_SQL.PARSE(v_cursor_id, v_cur_stmt, DBMS_SQL.NATIVE);
             EXCEPTION
             WHEN OTHERS THEN
                  v_error_message := 'ERROR:CURSOR FAILED: CURSOR_ID='||v_cur_id||' : '||v_dbid || ':' || p_cur_name || ':' || SQLCODE || ':' || SUBSTR(SQLERRM, 1, 256);
                  DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(v_error_message), v_error_message);
                  RETURN;

       END;
       DBMS_SQL.DESCRIBE_COLUMNS(v_cursor_id, v_num_columns, v_desc_tab);
       FOR v_col_num IN 1..v_num_columns
       
       -- Define columns from parsed cursor
       LOOP
          DBMS_SQL.DEFINE_COLUMN(v_cursor_id, v_col_num, v_string, 50); 
       END LOOP;
       
       v_rows_processed := dbms_sql.execute(v_cursor_id);
       -- Fetch rows and describe columns
       LOOP
           -- Execute the cursor
           IF DBMS_SQL.FETCH_ROWS(v_cursor_id) <= 0 THEN
               EXIT;
           END IF;
       
           -- Initialize the output row with the prefix
           v_row_count := v_row_count + 1;
           v_row_data := p_cur_name || v_placeholder || v_dbid || v_column_sep || v_extract_dt || v_column_sep || v_row_count || v_column_sep || v_open_p;
       
           -- Loop through the columns in the query to create name-value pairs in JSON format
           FOR v_col_num IN 1 .. v_num_columns LOOP
               DBMS_SQL.COLUMN_VALUE(v_cursor_id, v_col_num, v_string);
               v_row_data := v_row_data || if_gt_one(v_col_num) || nv_pair(v_desc_tab(v_col_num).col_name, v_string);
           END LOOP;
       
           -- Close the JSON parenthesis and add a line ending
           v_row_data := v_row_data || v_close_p || v_eol;
           DBMS_LOB.WRITEAPPEND(p_clob, LENGTH(v_row_data), v_row_data);
       END LOOP;
       --
       -- Add the final rowcount to the summary table
       v_summary(p_cur_name) := v_row_count;
       --
       -- Close the cursor
       DBMS_SQL.CLOSE_CURSOR(v_cursor_id);
    END;
    --
    -- MAIN
    BEGIN
    dbms_lob.createtemporary(:output_clob,true);
    dbms_lob.createtemporary(:mpack_summary_clob,true);
    dbms_lob.createtemporary(:MPACK_DBINFO_clob,true);
    dbms_lob.createtemporary(:MPACK_TRANSACTIONS_clob,true);
    dbms_lob.createtemporary(:MPACK_USERSCONNECTED_clob,true);
    dbms_lob.createtemporary(:MPACK_METRIC_CPU_clob,true);
    dbms_lob.createtemporary(:MPACK_HOST_clob,true);
    dbms_lob.createtemporary(:MPACK_SGA_PGA_METRIC_clob,true);
    dbms_lob.createtemporary(:MPACK_DBSIZE_clob,true);
    dbms_lob.createtemporary(:MPACK_DAILY_ARCH_METRIC_clob,true);
    dbms_lob.createtemporary(:MPACK_QUERIES_clob,true);
    dbms_lob.createtemporary(:MPACK_METRIC_clob,true);
    dbms_lob.createtemporary(:MPACK_BLOCKSIZE_clob,true);


    -- get basic database details
    get_database_identifiers(v_dbid,
                             v_dbname,
                             v_con_dbid,
                             v_pdb_con_id,
                             v_con_dbname,
                             v_pluggable_count,
                             v_unique_dbname,
                             v_resetlogs_scn,
                             v_instance_number,
                             v_instance_name,
                             v_instance_role,
                             v_hostname,
                             v_exadata_flag,
                             v_gg_flag,
                             v_host_list,
                             v_pdb_host_list,
                             v_version,
                             v_version_major,
                             v_version_minor,
                             v_multitenant);
 
    -- build database info clob

    v_dbinfo:='MPACK_DBINFO'||v_placeholder||  
            v_dbid||'|'||v_extract_dt||'|'||'0|'||'{'||
            '"'||'db_name'||'":"'||v_dbname||'",'||
            '"'||'con_dbid'||'":"'||to_char(v_con_dbid)||'",'||
            '"'||'pdb_con_id'||'":"'||to_char(v_pdb_con_id)||'",'||
            '"'||'con_dbname'||'":"'||v_con_dbname||'",'||
            '"'||'pluggable_count'||'":"'||to_char(v_pluggable_count)||'",'||
            '"'||'unique_dbname'||'":"'||v_unique_dbname||'",'||
            '"'||'resetlogs_scn'||'":"'||to_char(v_resetlogs_scn)||'",'||
            '"'||'instance_number'||'":"'||to_char(v_instance_number)||'",'||
            '"'||'instance_name'||'":"'||v_instance_name||'",'||
            '"'||'instance_role'||'":"'||v_instance_role||'",'||
            '"'||'hostname'||'":"'||v_hostname||'",'||
            '"'||'exadata_flag'||'":"'||v_exadata_flag||'",'||
            '"'||'gg_flag'||'":"'||v_gg_flag||'",'||
            '"'||'host_list'||'":"'||v_host_list||'",'||
            '"'||'pdb_host_list'||'":"'||v_pdb_host_list||'",'||
            '"'||'version'||'":"'||v_version||'",'||
            '"'||'version_major'||'":"'||to_char(v_version_major)||'",'||
            '"'||'version_minor'||'":"'||to_char(v_version_minor)||'",'||
            '"'||'multitenant'||'":"'||v_multitenant||'"'||
            '}'||
  chr(10);
    
    --dbms_lob.writeappend(v_dbinfo, dbms_lob.getlength(v_new_clob_record), v_new_clob_record);
    
    select v_dbinfo into :MPACK_DBINFO_clob from dual;
    
    --dbms_lob.freetemporary(v_dbinfo);
    
    -- build the output rows


    build_row('dummy',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:output_clob);
    build_row('MPACK_TRANSACTIONS',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_TRANSACTIONS_clob);
    build_row('MPACK_USERSCONNECTED',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_USERSCONNECTED_clob);
    build_row('MPACK_METRIC_CPU',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_METRIC_CPU_clob);
    build_row('MPACK_HOST',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_HOST_clob);
    build_row('MPACK_SGA_PGA_METRIC',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_SGA_PGA_METRIC_clob);
    build_row('MPACK_DBSIZE',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_DBSIZE_clob);
    build_row('MPACK_DAILY_ARCH_METRIC',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_DAILY_ARCH_METRIC_clob);
    build_row('MPACK_QUERIES',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_QUERIES_clob);
    build_row('MPACK_METRIC',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_METRIC_clob);
    build_row('MPACK_BLOCKSIZE',v_version_major,v_version_minor,v_multitenant,v_con_dbid,v_pluggable_count,10.2,:MPACK_BLOCKSIZE_clob);

    build_summary;
    END;
/
print output_clob
print MPACK_DBINFO_clob
print MPACK_TRANSACTIONS_clob
print MPACK_USERSCONNECTED_clob
print MPACK_METRIC_CPU_clob
print MPACK_HOST_clob
print MPACK_SGA_PGA_METRIC_clob
print MPACK_DBSIZE_clob
print MPACK_DAILY_ARCH_METRIC_clob
--print MPACK_QUERIES_clob
print MPACK_METRIC_clob
print MPACK_BLOCKSIZE_clob
print mpack_summary_clob
--exit

exit;
