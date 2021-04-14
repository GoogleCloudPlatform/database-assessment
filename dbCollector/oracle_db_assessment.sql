/*
Copyright 2021 Google LLC

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
--# DISCLAIMER: Copyright 2020 Google LLC. This software is provided as-is, without warranty or representation for any use or purpose. Your use of it is subject to your agreement with Google.
--#
--# Author: Eri Santos - Google PSO
--# Version: 3.1
--# Goal: This script intends to collect Oracle Database information to enable engineers and architects to consider:
--#	- Database Migration (Lift&Shift)
--#	- Database Modernization
--#

accept envtype char prompt "Please enter PROD if this is a PRODUCTION environment. Otherwise enter NON-PROD: "

--#Block for generating CSV
set colsep ,
set headsep off
set trimspool on
set pagesize 0
set feed off
set underline off

whenever sqlerror continue
whenever oserror continue
set echo off
set ver on feed on hea on scan on term on pause off wrap on doc on
ttitle off
btitle off
set termout off
set termout on
clear col comp brea

column instnc new_value v_inst noprint
column hostnc new_value v_host noprint
column horanc new_value v_hora noprint
column dbname new_value v_dbname noprint

SELECT host_name hostnc, instance_name instnc FROM v$instance
/
SELECT NAME dbname FROM v$database
/
SELECT to_CHAR(SYSDATE,'hh24miss') horanc FROM DUAL
/



set lines 600
set pages 200
set verify off
set feed off
column name format a100

col dbfullversion for a80
col dbversion for a10
col characterset for a30
col force_logging for a20

spool psodb_dbsummary_&v_host..&v_dbname..&v_inst..&v_hora..log


select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey,
        (select name from v$database) as db_name,
        (select CDB from v$database) as cdb,
	(select version from v$instance) as dbversion,
        (select banner from v$version where rownum < 2) as dbfullversion,
        (select log_mode from v$database) as log_mode,
        (select force_logging from v$database) as force_logging,
        (select (trunc(avg(conta)*avg(bytes)/1024/1024/1024)) from (select trunc(first_time) dia,count(*) conta from v$log_history where first_time >= trunc(sysdate) - 7 and first_time < trunc(sysdate) group by trunc(first_time)),v$log) as redo_gb_per_day,
        (select count(1) from gv$instance) as rac_dbinstaces,
        (select value from  nls_database_parameters a where a.parameter = 'NLS_LANGUAGE') || '_' ||
                        (select value from  nls_database_parameters a where a.parameter = 'NLS_TERRITORY') || '.' ||
                        (select value from  nls_database_parameters a where a.parameter = 'NLS_CHARACTERSET') as characterset,
        (select platform_name from v$database) as platform_name,
        (select To_Char(startup_time,'mm/dd/rr hh24:mi:ss') FROM v$instance) as startup_time,
        (select count(1) from cdb_users where username not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')) as user_schemas,
        (select trunc(sum(bytes/1024/1024)) from v$sgastat where name = 'buffer_cache') buffer_cache_mb,
        (select trunc(sum(bytes/1024/1024)) from v$sgastat where pool = 'shared pool') shared_pool_mb,
        (select round(value/1024/1024,0) from v$pgastat where name  = 'total PGA allocated') as total_pga_allocated_mb,
        (select (trunc(sum(bytes)/1024/1024/1024)) from cdb_data_files) db_size_allocated_gb,
        (select (trunc(sum(bytes)/1024/1024/1024)) from cdb_segments where owner not in ('SYS','SYSTEM')) as db_size_in_use_gb,
        (select (trunc(sum(bytes)/1024/1024/1024)) from cdb_segments where owner not in ('SYS','SYSTEM') and (owner,segment_name) in (select owner,table_name from cdb_tab_columns where data_type like '%LONG%')) as db_long_size_gb,
        (select database_role from v$database) as dg_database_role,
        (select protection_mode from v$database) as dg_protection_mode,
        (select protection_level from v$database) as dg_protection_level
from dual;

spool off



--spool psodb_dboverview_&v_host..&v_dbname..&v_inst..&v_hora..log

/*
select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, metric,name from (
select 1 ordem,'DB Name' metric, name from v$database
union ALL
select 1, 'Schemas', To_Char(count(1)) from cdb_users where username not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
UNION ALL
SELECT 1, 'Startup Time', To_Char(startup_time,'dd/mm/rr hh24:mi:ss') FROM v$instance
UNION ALL
select 1.1, 'CDB', CDB from v$database
union all
select 1.2, 'DB Instances', to_char((select count(1) from gv$instance)) from dual 
union all
select 2,'Archive Log Mode / Force logging', log_mode || ' / ' FORCE_LOGGING from v$database
union all
select 2.1,'Dataguard (Protection Level / Protection Mode / DB Role)', PROTECTION_LEVEL || ' / ' || PROTECTION_MODE || ' / ' || DATABASE_ROLE from v$database
union all
select 3,'Environment Type', null from dual
union all
select 4,'Characterset',(select value from  nls_database_parameters a where a.parameter = 'NLS_LANGUAGE') || '_' ||
                        (select value from  nls_database_parameters a where a.parameter = 'NLS_TERRITORY') || '.' ||
                        (select value from  nls_database_parameters a where a.parameter = 'NLS_CHARACTERSET')  from dual
union all
select 5,'Oracle Release', banner from v$version where rownum < 2
union all
select 6,'Platform', platform_name from v$database
union all
select 8,'Redo Generated',to_char(trunc(avg(conta)*avg(bytes)/1024/1024/1024))||' Gb/day' from (select trunc(first_time) dia,count(*) conta from v$log_history where first_time >= trunc(sysdate) - 7 and first_time < trunc(sysdate) group by trunc(first_time)),v$log
union all
select 9,'SGA (Buffer Cache / Shared Pool)',(select trunc(sum(bytes/1024/1024))||' Mb / ' from v$sgastat where name = 'buffer_cache')||(select trunc(sum(bytes/1024/1024))||' Mb' from v$sgastat where pool = 'shared pool') from dual
union all
select 9.1,'PGA (Allocated)', (select round(value/1024/1024,0) || ' Mb ' from v$pgastat where name  = 'total PGA allocated') from dual
union all
select 10,'Oracle Clusterware Version',  null from dual
union all
select 11,'Oracle ASM Version',  null from dual
union all
select 12,'Oracle Home Path',  null from dual
union all
select 13,'Database Size Allocated', to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_data_files
union all
select 14,'Database Size in Use'   , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM')
union all
select 15,'Database TABLE Size'    , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type like 'TABLE%' or segment_type in ('LOBSEGMENT','LOB PARTITION')
union all
select 16,'Database INDEX Size'    , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type like '%INDEX%'
union all
select 17,'Database LONG Size'     , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and (owner,segment_name) in (select owner,table_name from cdb_tab_columns where data_type like '%LONG%')
union all
select 18,'Database LOB Size'      , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type in ('LOBSEGMENT','LOB PARTITION','LOBINDEX')
union all
select 19,'Database TAB PART Size' , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type in ('TABLE PARTITION','TABLE SUBPARTITION','LOB PARTITION')
union all
select 21,'Database TAB NPART Size', to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type in ('TABLE','LOBSEGMENT')
union all
select 22,'Database IND PART Size' , to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type in ('INDEX PARTITION','INDEX SUBPARTITION')
union all
select 23,'Database IND NPART Size', to_char(trunc(sum(bytes)/1024/1024/1024))||' Gb' from cdb_segments where owner not in ('SYS','SYSTEM') and segment_type in ('INDEX')
order by 1) a;
*/

--spool off

set lines 300

spool psodb_pdbsinfo_&v_host..&v_dbname..&v_inst..&v_hora..log

col PDB_NAME for a30

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, DBID, PDB_ID, PDB_NAME, STATUS, LOGGING from cdb_pdbs;

spool off

spool psodb_pdbsopenmode_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, CON_ID, NAME, OPEN_MODE, TOTAL_SIZE/1024/1024/1024 TOTAL_GB from v$pdbs;

spool off

spool psodb_dbinstances_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, INST_ID, INSTANCE_NAME, HOST_NAME, VERSION, STATUS, DATABASE_STATUS, INSTANCE_ROLE
from gv$instance;

spool off

spool psodb_usedspacedetails_&v_host..&v_dbname..&v_inst..&v_hora..log

col OWNER for a30
col TABLESPACE_NAME for a20
set lines 340

SELECT '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.*
from (
SELECT 
CON_ID, 
OWNER, 
SEGMENT_TYPE, 
TABLESPACE_NAME, 
FLASH_CACHE, 
INMEMORY, 
GROUPING(CON_ID) IN_CON_ID,
GROUPING(OWNER) IN_OWNER,
GROUPING(SEGMENT_TYPE) IN_SEGMENT_TYPE,
GROUPING(TABLESPACE_NAME) IN_TABLESPACE_NAME,
GROUPING(FLASH_CACHE) IN_FLASH_CACHE,
GROUPING(INMEMORY) IN_INMEMORY,
ROUND(SUM(BYTES)/1024/1024/1024,0) GB
FROM cdb_segments
where owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
GROUP BY
	GROUPING SETS(
		(),
		(CON_ID),
		(OWNER),
		(SEGMENT_TYPE),
		(TABLESPACE_NAME),
		(FLASH_CACHE),
		(INMEMORY),
		(CON_ID, OWNER),
		(CON_ID, OWNER, FLASH_CACHE, INMEMORY)
)
) a;


spool off

--compute sum of tab on report
--compute sum of table_gb on report
--compute sum of part on report
--compute sum of part_gb on report
--compute sum of subpart on report
--compute sum of subpart_gb on report
--compute sum of total_gbytes on report

--compute sum of basic on report
--compute sum of oltp on report
--compute sum of query_low on report
--compute sum of query_high on report
--compute sum of archive_low on report
--compute sum of archive_high on report
--compute sum of total_gb on report

--break on report

set underline off
spool psodb_compressbytable_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.*
from (
select con_id,
       owner,
       sum(table_count) tab,trunc(sum(table_gbytes)) table_gb,
       sum(partition_count) part,trunc(sum(partition_gbytes)) part_gb,
       sum(subpartition_count) subpart,trunc(sum(subpartition_gbytes)) subpart_gb,
       trunc(sum(table_gbytes)+sum(partition_gbytes)+sum(subpartition_gbytes)) total_gbytes from (
select t.con_id, t.owner,count(*) table_count,sum(bytes/1024/1024/1024) table_gbytes,0 partition_count,0 partition_gbytes,0 subpartition_count,0 subpartition_gbytes
from cdb_tables t, cdb_segments s
where t.CON_ID=s.CON_ID and t.owner = s.owner and t.table_name = s.segment_name and s.partition_name is null and compression = 'ENABLED'
group by t.CON_ID, t.owner
union all
select t.con_id, t.table_owner owner,0,0,count(*),sum(bytes/1024/1024/1024),0,0
from cdb_tab_partitions t, cdb_segments s
where t.CON_ID=s.CON_ID and t.table_owner = s.owner and t.table_name = s.segment_name and t.partition_name = s.partition_name and compression = 'ENABLED'
group by t.CON_ID, t.table_owner
union all
select t.con_id, t.table_owner owner,0,0,0,0,count(*),sum(bytes/1024/1024/1024)
from cdb_tab_subpartitions t, cdb_segments s
where t.CON_ID=s.CON_ID and t.table_owner = s.owner and t.table_name = s.segment_name and t.subpartition_name = s.partition_name and compression = 'ENABLED'
group by t.CON_ID, t.table_owner)
group by con_id, owner
having trunc(sum(table_gbytes)+sum(partition_gbytes)+sum(subpartition_gbytes)) > 0
) a
order by 10 desc;

spool off

spool psodb_compressbytype_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.*
from (
select con_id,
       owner,
       trunc(sum(decode(compress_for,'BASIC'       ,gbytes,0))) basic,
       trunc(sum(decode(compress_for,'OLTP'        ,gbytes,
                                     'ADVANCED'    ,gbytes,
                                      0))) oltp,
       trunc(sum(decode(compress_for,'QUERY LOW'   ,gbytes,0))) query_low,
       trunc(sum(decode(compress_for,'QUERY HIGH'  ,gbytes,0))) query_high,
       trunc(sum(decode(compress_for,'ARCHIVE LOW' ,gbytes,0))) archive_low,
       trunc(sum(decode(compress_for,'ARCHIVE HIGH',gbytes,0))) archive_high,
       trunc(sum(gbytes)) total_gb from (
select t.con_id, t.owner,t.compress_for,sum(bytes/1024/1024/1024) gbytes
from cdb_tables t, cdb_segments s
where t.CON_ID=s.CON_ID and t.owner = s.owner and t.table_name = s.segment_name and s.partition_name is null and compression = 'ENABLED'
group by t.con_id, t.owner,t.compress_for
union all
select t.con_id, t.table_owner,t.compress_for,sum(bytes/1024/1024/1024) gbytes
from cdb_tab_partitions t, cdb_segments s
where t.CON_ID=s.CON_ID and t.table_owner = s.owner and t.table_name = s.segment_name and t.partition_name = s.partition_name and compression = 'ENABLED'
group by t.con_id, t.table_owner,t.compress_for
union all
select t.con_id, t.table_owner,t.compress_for,sum(bytes/1024/1024/1024) gbytes
from cdb_tab_subpartitions t, cdb_segments s
where t.CON_ID=s.CON_ID and t.table_owner = s.owner and t.table_name = s.segment_name and t.subpartition_name = s.partition_name and compression = 'ENABLED'
group by t.con_id, t.table_owner,t.compress_for)
group by con_id, owner
having trunc(sum(gbytes)) > 0
) a
order by total_gb desc;

spool off
clear break
clear compute


spool psodb_spacebyownersegtype_&v_host..&v_dbname..&v_inst..&v_hora..log

column owner format a30
column segment_type format a30

SET pages 100
--break on report
--compute sum of total_gb on report

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.*
from (
select a.con_id,  a.owner, decode(a.segment_type,'TABLE','TABLE',
                                      'TABLE PARTITION','TABLE',
                                      'TABLE SUBPARTITION','TABLE',
                                      'INDEX','INDEX',
                                      'INDEX PARTITION','INDEX',
                                      'INDEX SUBPARTITION','INDEX',
                                      'LOB','LOB',
                                      'LOB PARTITION','LOB',
                                      'LOBSEGMENT','LOB',
                                      'LOBINDEX','LOB','OTHERS') segment_type, trunc(sum(a.bytes)/1024/1024/1024) total_gb
from cdb_segments a
where a.owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
group by a.con_id, a.owner,decode(a.segment_type,'TABLE','TABLE',
                                      'TABLE PARTITION','TABLE',
                                      'TABLE SUBPARTITION','TABLE',
                                      'INDEX','INDEX',
                                      'INDEX PARTITION','INDEX',
                                      'INDEX SUBPARTITION','INDEX',
                                      'LOB','LOB',
                                      'LOB PARTITION','LOB',
                                      'LOBSEGMENT','LOB',
                                      'LOBINDEX','LOB','OTHERS')
having trunc(sum(a.bytes)/1024/1024/1024) >= 1
) a
order by  total_gb desc;
clear break
clear compute

spool off

col tablespace_name FOR a35
col extent_management FOR a20
col allocation_type FOR a10
col segment_space_management FOR a20
--break ON report
--compute Sum OF estd_ganho_mb ON report

spool psodb_spacebytablespace_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.*
from (
select b.tablespace_name, b.extent_management, b.allocation_type, b.segment_space_management, sum(estd_ganho_mb) estd_ganho_mb
from (
select b.tablespace_name, b.extent_management, b.allocation_type, b.segment_space_management, a.initial_extent/1024 inital_kb, a.owner, a.segment_name, a.partition_name, (a.bytes)/1024 segsize_kb, trunc((a.initial_extent/1024) / ((a.bytes)/1024) * 100) perc,trunc(((a.bytes)/1024/100)*trunc((a.initial_extent/1024) / ((a.bytes)/1024) * 100)/1024) estd_ganho_mb
from cdb_segments a
inner join cdb_tablespaces b
on a.tablespace_name = b.tablespace_name
where a.owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE',
        'SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
and b.allocation_type = 'SYSTEM' and a.initial_extent = a.bytes
) b
group by b.tablespace_name, b.extent_management, b.allocation_type, b.segment_space_management
union all
select b.tablespace_name, b.extent_management, b.allocation_type, b.segment_space_management, sum(estd_ganho_mb) estd_ganho_mb
from (
select b.tablespace_name, b.extent_management, b.allocation_type, b.segment_space_management, a.initial_extent/1024 inital_kb, a.owner, a.segment_name, a.partition_name, (a.bytes)/1024 segsize_kb, trunc((a.initial_extent/1024) / ((a.bytes)/1024) * 100) perc,trunc(((a.bytes)/1024/100)*trunc((a.initial_extent/1024) / ((a.bytes)/1024) * 100)/1024) estd_ganho_mb
from cdb_segments a
inner join cdb_tablespaces b
on a.tablespace_name = b.tablespace_name
where a.owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE',
        'SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
and b.allocation_type != 'SYSTEM'
) b
group by b.tablespace_name, b.extent_management, b.allocation_type, b.segment_space_management
) a;

spool off

clear break
clear compute


column owner format a30
column table_name format a30
column partition_name format a30
column mbytes format 999999999999999



column statistic_name format a30
column value format 999999999999999


SET pages 100 lines 390
col high_value FOR a10

spool psodb_freespaces_&v_host..&v_dbname..&v_inst..&v_hora..log

column tablespace format a30
--column total_gb format 999,999,999,999.99
--column used_mb format 999,999,999,999.99
--column free_mb format 999,999,999.99
column pct_used format 999.99
column graph format a25 heading "GRAPH (X=5%)"
column status format a10
--compute sum of total_mb on report
--compute sum of used_mb on report
--compute sum of free_mb on report
--break on report
set lines 300 pages 100

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.*
from (
select  total.con_id,
        total.ts tablespace,
        DECODE(total.mb,null,'OFFLINE',dbat.status) status,
        Trunc(total.mb/1024) total_gb,
        Trunc(NVL(total.mb - free.mb,total.mb)/1024) used_gb,
        Trunc(NVL(free.mb,0)/1024) free_gb,
        DECODE(total.mb,NULL,0,NVL(ROUND((total.mb - free.mb)/(total.mb)*100,2),100)) pct_used,
        CASE WHEN (total.mb IS NULL) THEN '['||RPAD(LPAD('OFFLINE',13,'-'),20,'-')||']'
        ELSE '['|| DECODE(free.mb,
                             null,'XXXXXXXXXXXXXXXXXXXX',
                             NVL(RPAD(LPAD('X',trunc((100-ROUND( (free.mb)/(total.mb) * 100, 2))/5),'X'),20,'-'),
               '--------------------'))||']'
         END as GRAPH
from
        (select con_id, tablespace_name ts, sum(bytes)/1024/1024 mb from cdb_data_files group by con_id, tablespace_name) total,
        (select con_id, tablespace_name ts, sum(bytes)/1024/1024 mb from cdb_free_space group by con_id, tablespace_name) free,
        cdb_tablespaces dbat
where total.ts=free.ts(+) and
      total.ts=dbat.tablespace_name and
      total.con_id = free.con_id and
      total.con_id = dbat.con_id
UNION ALL
select  sh.con_id,
        sh.tablespace_name,
        'TEMP',
        SUM(sh.bytes_used+sh.bytes_free)/1024/1024 total_mb,
        SUM(sh.bytes_used)/1024/1024 used_mb,
        SUM(sh.bytes_free)/1024/1024 free_mb,
        ROUND(SUM(sh.bytes_used)/SUM(sh.bytes_used+sh.bytes_free)*100,2) pct_used,
        '['||DECODE(SUM(sh.bytes_free),0,'XXXXXXXXXXXXXXXXXXXX',
             NVL(RPAD(LPAD('X',(TRUNC(ROUND((SUM(sh.bytes_used)/SUM(sh.bytes_used+sh.bytes_free))*100,2)/5)),'X'),20,'-'),
                '--------------------'))||']'
FROM v$temp_space_header sh
GROUP BY con_id, tablespace_name
) a
order by GRAPH;


spool off 

--compute sum of sum_gb on report
--compute sum of estd_ganho on report


set pages 9000 

spool psodb_dblinks_&v_host..&v_dbname..&v_inst..&v_hora..log

col owner for a20
col DB_LINK for a50
col USERNAME for a20
col HOST for a30
set lines 340

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, CON_ID, OWNER, DB_LINK, HOST, CREATED
from CDB_DB_LINKS
where owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM');

spool off

col name for a80
col value for a60
col DEFAULT_VALUE for a30
col ISDEFAULT for a6
set lines 300

spool psodb_dbparameters_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, INST_ID, con_id, replace(NAME,',','/') name, replace(substr(VALUE,1,60),',','/') value, replace(substr(DEFAULT_VALUE,1,30),',','/') DEFAULT_VALUE, ISDEFAULT
from gv$parameter
order by 2,3;

spool off

spool psodb_dbfeatures_&v_host..&v_dbname..&v_inst..&v_hora..log

set lines 320 
col name for a70
col feature_info for a76

--select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, con_id, name, currently_used, detected_usages, total_samples, to_char(last_usage_date, 'MM/DD/YY HH24:MI') last_usage from cdb_feature_usage_statistics
--order by currently_used desc, name asc;

--retired 
--(case when length(feature_info) > 80 then
--substr(feature_info, 1, 76) || ' ...' else
--feature_info
--end) featinfo

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, con_id, replace(name,',','/') name, currently_used, detected_usages, total_samples, to_char(first_usage_date,'MM/DD/YY HH24:MI') first_usage,
to_char(last_usage_date, 'MM/DD/YY HH24:MI') last_usage,
aux_count
from cdb_feature_usage_statistics order by name;


spool off

spool psodb_dbhwmarkstatistics_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, description, highwater, last_value
from dba_high_water_mark_statistics
order by description;

spool off

spool psodb_cpucoresusage_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, to_char(timestamp, 'MM/DD/YY HH24:MI') dt,
cpu_count, cpu_core_count, cpu_socket_count
from dba_cpu_usage_statistics
order by timestamp;

spool off

col object_type for a20
col owner for a40

spool psodb_dbobjects_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, a.* from (
SELECT con_id,
       owner,
       object_type,
       editionable,
       Count(1) count,
       Grouping(con_id)      in_con_id,
       Grouping(owner)       in_owner,
       Grouping(object_type) in_OBJECT_TYPE,
       Grouping(editionable) in_EDITIONABLE
FROM   cdb_objects
WHERE owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
             'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
             'EXFSYS', 'LBACSYS', 'MDSYS',
             'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
             'TRACESVR', 'TSMSYS',
             'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
             'WMSYS', 'APPQOSSYS',
             'FLOWS_FILES', 'OWBSYS', 'SCOTT',
             'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
             'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
             'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
GROUP  BY grouping sets ( ( con_id, object_type ), 
                          ( con_id, owner, editionable, object_type )
                        )
) a;

spool off

col OWNER for a30
col NAME for a40
col TYPE for a40
set lines 400

spool psodb_sourcecode_&v_host..&v_dbname..&v_inst..&v_hora..log

select pkey, con_id, owner, type, sum(nr_lines) sum_nr_lines, count(1) qt_objs, 
       sum(count_utl) sum_nr_lines_w_utl, sum(count_dbms) sum_nr_lines_w_dbms,
       sum(count_exec_im) count_exec_im, sum(count_dbms_sql) count_dbms_sql,
       sum(count_dbms_utl) sum_nr_lines_w_dbms_utl, sum(count_total) sum_count_total from (
select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, CON_ID, OWNER, NAME, TYPE, MAX(LINE) NR_LINES,
       count(case when lower(text) like '%utl_%' then 1 end) count_utl,
       count(case when lower(text) like '%dbms_%' then 1 end) count_dbms,
       count(case when lower(text) like '%dbms_%' and lower(text) like '%utl_%' then 1 end) count_dbms_utl,
       count(case when lower(text) like '%execute%immediate%' then 1 end) count_exec_im,
       count(case when lower(text) like '%dbms_sql%' then 1 end) count_dbms_sql,
       count(1) count_total
from cdb_source
where owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', CON_ID, OWNER, NAME, TYPE)
group by pkey, con_id, owner, type;

spool off



spool psodb_partsubparttypes_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, CON_ID, OWNER, PARTITIONING_TYPE, SUBPARTITIONING_TYPE, count(1)
from cdb_part_tables
where owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', CON_ID, OWNER, PARTITIONING_TYPE, SUBPARTITIONING_TYPE;

spool off

spool psodb_indexestypes_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, CON_ID, OWNER, INDEX_TYPE, count(1)
from cdb_indexes
where owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', CON_ID, OWNER, INDEX_TYPE;

spool off

col owner for a50
col data_type for a60

spool psodb_datatypes_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, CON_ID, OWNER, DATA_TYPE, count(1)
from cdb_tab_columns
where owner not in ('SYS', 'SYSTEM', 'OUTLN', 'AWR_STAGE', 'CSMIG',
        'CTXSYS', 'DBSNMP', 'DIP', 'DMSYS', 'DSSYS',
        'EXFSYS', 'LBACSYS', 'MDSYS',
        'ORACLE_OCM', 'ORDPLUGINS', 'ORDSYS', 'PERFSTAT',
        'TRACESVR', 'TSMSYS',
        'XDB', 'APEX_030200', 'SYSMAN', 'OLAPSYS', 'ORDDATA',
        'WMSYS', 'APPQOSSYS',
        'FLOWS_FILES', 'OWBSYS', 'SCOTT',
        'SPATIAL_WFS_ADMIN_USR', 'SPATIAL_CSW_ADMIN_USR',
        'MGMT_VIEW', 'APEX_PUBLIC_USER', 'ANONYMOUS',
        'SQLTXPLAIN', 'SQLTXADMIN', 'TRCANLZR','HR','OE','SI_INFORMTN_SCHEMA','XS$NULL','IX','OWBSYS_AUDIT','MDDATA','SH','BI','PM')
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', CON_ID, OWNER, DATA_TYPE;

spool off

spool psodb_tablesnopk_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, con_id, owner, sum(pk) pk, sum(uk) uk, sum(ck) ck, sum(ri) ri, sum(vwck) vwck,
       sum(vwro) vwro, sum(hashexpr) hashexpr, sum(suplog) suplog, count(distinct  table_name) num_tables, count(1) total_cons from (
select a.con_id, a.owner, a.table_name,
       decode(b.constraint_type,'P', 1, null) pk,
       decode(b.constraint_type,'U', 1, null) uk,
       decode(b.constraint_type,'C', 1, null) ck,
       decode(b.constraint_type,'R', 1, null) ri,
       decode(b.constraint_type,'V', 1, null) vwck,
       decode(b.constraint_type,'O', 1, null) vwro,
       decode(b.constraint_type,'H', 1, null) hashexpr,
       decode(b.constraint_type,'F', 1, null) refcolcons,
       decode(b.constraint_type,'S', 1, null) suplog
from cdb_tables a
left outer join cdb_constraints b
on a.con_id = b.con_id and a.owner = b.owner and a.table_name = b.table_name )
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', con_id, owner;

spool off

spool psodb_systemstats_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, SNAME, PNAME, PVAL1, PVAL2 from sys.aux_stats$;

spool off

col Comments for a60

spool psodb_patchlevel_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey
,      to_char(action_time, 'mm/dd/rr hh24:mi') as "Time"
,      action as "Action"
,      namespace as "Namespace"
,      version as "Version"
,      id as "ID"
,      comments as "Comments"
from  sys.REGISTRY$HISTORY
order by action_time;

spool off

column min_snapid new_value v_min_snapid noprint
column max_snapid new_value v_max_snapid noprint
column total_secs new_value v_total_secs noprint

SELECT min(SNAP_ID) min_snapid, max(snap_id) max_snapid, (to_number(cast(max(END_INTERVAL_TIME) as date)-cast(min(BEGIN_INTERVAL_TIME) as date))*60*60*24) total_secs from dba_hist_snapshot where BEGIN_INTERVAL_TIME > (sysdate-30)
/

set lines 560
col STAT_NAME for a64
col SUM_VALUE for 99999999999999999999
set pages 50000
col VALUE for 99999999999999999999
col PERC50 for 99999999999999999999
col PERC75 for 99999999999999999999
col PERC90 for 99999999999999999999
col PERC95 for 99999999999999999999
col PERC100 for 99999999999999999999
col hh24_total_secs for 99999999999999999999
col avg_value for 99999999999999999999
col mode_value for 99999999999999999999
col median_value for 99999999999999999999
col min_value for 99999999999999999999
col max_value for 99999999999999999999
col sum_value for 99999999999999999999
col count for 99999999999999999999
col coun for 99999999999999999999


spool psodb_awrhistsysmetrichist_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, hsm.CON_ID, hsm.DBID, hsm.INSTANCE_NUMBER, to_char(hsm.BEGIN_TIME, 'hh24') hour, hsm.METRIC_NAME, hsm.METRIC_UNIT, --dhsnap.STARTUP_TIME,
       avg(hsm.value) avg_value, stats_mode(hsm.value) mode_value, median(hsm.value) median_value, 
       min(hsm.value) min_value, max(hsm.value) max_value, sum(hsm.value) sum_value,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY hsm.VALUE DESC) AS "PERC50",
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY hsm.VALUE DESC) AS "PERC75",
       PERCENTILE_CONT(0.10) WITHIN GROUP (ORDER BY hsm.VALUE DESC) AS "PERC90",
       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY hsm.VALUE DESC) AS "PERC95",
       PERCENTILE_CONT(0) WITHIN GROUP (ORDER BY hsm.VALUE DESC) AS "PERC100"
 from DBA_HIST_SYSMETRIC_HISTORY hsm
 inner join DBA_HIST_SNAPSHOT dhsnap
 on hsm.SNAP_ID = dhsnap.SNAP_ID and hsm.INSTANCE_NUMBER = dhsnap.INSTANCE_NUMBER and hsm.DBID = dhsnap.DBID
 where hsm.SNAP_ID between '&&v_min_snapid' and '&&v_max_snapid'
 group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', hsm.CON_ID, hsm.DBID, hsm.INSTANCE_NUMBER, to_char(hsm.BEGIN_TIME, 'hh24'), hsm.METRIC_NAME, hsm.METRIC_UNIT--, dhsnap.STARTUP_TIME
 order by hsm.con_id, hsm.DBID, hsm.INSTANCE_NUMBER, hsm.metric_name, to_char(hsm.BEGIN_TIME, 'hh24');

spool off


--spool psodb_awrhistsysstat_&v_host..&v_dbname..&v_inst..&v_hora..log

/*with v_sysstat_all as (
select ss.snap_id, ss.CON_ID, ss.DBID, ss.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24') hh24, STAT_NAME, VALUE, (to_number(cast(END_INTERVAL_TIME as date)-cast(BEGIN_INTERVAL_TIME as date))*60*60*24) snap_total_secs,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by ss.CON_ID, ss.DBID, ss.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),stat_name) AS "PERC50",
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by ss.CON_ID, ss.DBID, ss.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),stat_name) AS "PERC75",
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by ss.CON_ID, ss.DBID, ss.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),stat_name) AS "PERC90",
       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by ss.CON_ID, ss.DBID, ss.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),stat_name) AS "PERC95",
       PERCENTILE_CONT(0) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by ss.CON_ID, ss.DBID, ss.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),stat_name) AS "PERC100"
from dba_hist_sysstat ss
inner join dba_hist_snapshot snap
on ss.snap_id = snap.snap_id
where (STAT_NAME like 'physical read%'
or STAT_NAME like 'physical write%'
or STAT_NAME like 'cell%'
or STAT_NAME like 'HCC%'
or STAT_NAME like 'HSC%'
or STAT_NAME like 'Infiniband%'
or STAT_NAME like 'Parallel%'
or STAT_NAME like 'Workload Capture%'
or STAT_NAME like 'backup%'
or STAT_NAME like 'commit%'
or STAT_NAME like 'lob%'
or STAT_NAME like 'flash%'
or STAT_NAME like 'parse%'
or STAT_NAME like 'table%'
or STAT_NAME like 'workarea%'
or STAT_NAME in ('DB time','DDL statements parallelized','DML statements parallelized','consistent gets','db block gets','db block changes','execute count','lob reads','lob writes','logons cumulative','logons current','opened cursors cumulative','opened cursors current','queries parallelized','recursive cpu usage','redo blocks written','redo size','redo write time','redo writes','session cursor cache count','session cursor cache hits','session logical reads','session pga memory','session pga memory max','session uga memory','session uga memory max','sorts (disk)','sorts (memory)','sorts (rows)','transaction rollbacks','user I/O wait time','user calls,','user commits','user logons cumulative','user logouts cumulative','user rollbacks'))
and ss.SNAP_ID between '&&v_min_snapid' and '&&v_max_snapid'
) 
select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, '&&v_total_secs' total_awr_secs,CON_ID, DBID, INSTANCE_NUMBER, hh24, STAT_NAME, sum(snap_total_secs) hh24_total_secs, avg(value) avg_value, stats_mode(value) mode_value, median(value) median_value, avg(PERC50) PERC50, avg(PERC75) PERC75, avg(PERC90) PERC90, avg(PERC95) PERC95, avg(PERC100) PERC100, min(value) min_value, max(value) max_value, sum(value) sum_value, count(1) count
from v_sysstat_all
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora','&&v_total_secs', CON_ID, DBID, INSTANCE_NUMBER, hh24, STAT_NAME;
*/

--spool off



--spool psodb_awrhistsystimemodel_&v_host..&v_dbname..&v_inst..&v_hora..log

/*
with v_systimemodel_all as (
select stm.CON_ID, stm.DBID, stm.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24') hh24, stm.STAT_NAME, VALUE, (to_number(cast(END_INTERVAL_TIME as date)-cast(BEGIN_INTERVAL_TIME as date))*60*60*24) snap_total_secs,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by stm.CON_ID, stm.DBID, stm.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'), stat_name) AS "PERC50",
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by stm.CON_ID, stm.DBID, stm.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'), stat_name) AS "PERC75",
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by stm.CON_ID, stm.DBID, stm.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'), stat_name) AS "PERC90",
       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by stm.CON_ID, stm.DBID, stm.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'), stat_name) AS "PERC95",
       PERCENTILE_CONT(0) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by stm.CON_ID, stm.DBID, stm.INSTANCE_NUMBER,to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),stat_name) AS "PERC100"
from dba_hist_sys_time_model stm
inner join dba_hist_snapshot snap
on stm.snap_id = snap.snap_id
where stm.SNAP_ID between '&&v_min_snapid' and '&&v_max_snapid'
)
select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, '&&v_total_secs' total_awr_secs, CON_ID, DBID, INSTANCE_NUMBER, HH24, STAT_NAME, sum(snap_total_secs) hh24_total_secs, avg(value) avg_value, stats_mode(value) mode_value, median(value) median_value, avg(PERC50) PERC50, avg(PERC75) PERC75, avg(PERC90) PERC90, avg(PERC95) PERC95, avg(PERC100) PERC100, min(value) min_value, max(value) max_value, sum(value) sum_value, count(1) count
from v_systimemodel_all
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', '&&v_total_secs', CON_ID, DBID, INSTANCE_NUMBER, HH24, STAT_NAME;
*/

--spool off


spool psodb_awrhistosstat_&v_host..&v_dbname..&v_inst..&v_hora..log

with v_osstat_all as (
select os.CON_ID, os.DBID, os.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24') hh24, os.STAT_NAME, VALUE, (to_number(cast(END_INTERVAL_TIME as date)-cast(BEGIN_INTERVAL_TIME as date))*60*60*24) snap_total_secs,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by os.CON_ID, os.DBID, os.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),os.stat_name) AS "PERC50",
       PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by os.CON_ID, os.DBID, os.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),os.stat_name) AS "PERC75",
       PERCENTILE_CONT(0.1) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by os.CON_ID, os.DBID, os.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),os.stat_name) AS "PERC90",
       PERCENTILE_CONT(0.05) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by os.CON_ID, os.DBID, os.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),os.stat_name) AS "PERC95",
       PERCENTILE_CONT(0) WITHIN GROUP (ORDER BY VALUE DESC) over (partition by os.CON_ID, os.DBID, os.INSTANCE_NUMBER, to_char(snap.BEGIN_INTERVAL_TIME,'hh24'),os.stat_name) AS "PERC100"
from dba_hist_osstat os
Inner join dba_hist_snapshot snap
on os.snap_id = snap.snap_id
where os.SNAP_ID between '&&v_min_snapid' and '&&v_max_snapid'
)
select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, '&&v_total_secs' total_awr_secs, CON_ID, DBID, INSTANCE_NUMBER, hh24, STAT_NAME, sum(snap_total_secs) hh24_total_secs, avg(value) avg_value, stats_mode(value) mode_value, median(value) median_value, avg(PERC50) PERC50, avg(PERC75) PERC75, avg(PERC90) PERC90, avg(PERC95) PERC95, avg(PERC100) PERC100, min(value) min_value, max(value) max_value, sum(value) sum_value, count(1) count
from v_osstat_all
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', '&&v_total_secs', CON_ID, DBID, INSTANCE_NUMBER, hh24, STAT_NAME;

spool off

set pages 50000

spool psodb_awrhistcmdtypes_&v_host..&v_dbname..&v_inst..&v_hora..log

select '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey, to_char(c.BEGIN_INTERVAL_TIME,'hh24') hh24,b.command_type, count(1) coun,avg(BUFFER_GETS_DELTA) AVG_BUFFER_GETS, avg(ELAPSED_TIME_DELTA) AVG_ELASPED_TIME, avg(ROWS_PROCESSED_DELTA) AVG_ROWS_PROCESSED, avg(EXECUTIONS_DELTA) AVG_EXECUTIONS,
       avg(CPU_TIME_DELTA) AVG_CPU_TIME, avg(IOWAIT_DELTA) AVG_IOWAIT, avg(CLWAIT_DELTA) AVG_CLWAIT, avg(APWAIT_DELTA) AVG_APWAIT, avg(CCWAIT_DELTA) AVG_CCWAIT, avg(PLSEXEC_TIME_DELTA) AVG_PLSEXEC_TIME
from DBA_HIST_SQLSTAT a
inner join DBA_HIST_SQLTEXT b
on (a.con_id = b.con_id and a.sql_id = b.sql_id)
inner join DBA_HIST_SNAPSHOT c
on (a.snap_id = c.snap_id)
where a.SNAP_ID between '&&v_min_snapid' and '&&v_max_snapid'
group by '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', to_char(c.BEGIN_INTERVAL_TIME,'hh24'), b.command_type;

spool off
