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

--accept envtype char prompt "Please enter PROD if this is a PRODUCTION environment. Otherwise enter NON-PROD: "

--#Block for generating CSV
set colsep ||
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


SELECT host_name     hostnc,
       instance_name instnc
FROM   v$instance
/

SELECT name dbname
FROM   v$database
/

SELECT TO_CHAR(SYSDATE, 'hh24miss') horanc
FROM   dual
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

spool opdb__dbsummary__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                                            AS pkey,
       (SELECT dbid
        FROM   v$database)                                                      AS dbid,
       (SELECT name
        FROM   v$database)                                                      AS db_name,
       (SELECT version
        FROM   v$instance)                                                      AS dbversion,
       (SELECT banner
        FROM   v$version
        WHERE  ROWNUM < 2)                                                      AS dbfullversion,
       (SELECT log_mode
        FROM   v$database)                                                      AS log_mode,
       (SELECT force_logging
        FROM   v$database)                                                      AS force_logging,
       (SELECT ( TRUNC(AVG(conta) * AVG(bytes) / 1024 / 1024 / 1024) )
        FROM   (SELECT TRUNC(first_time) dia,
                       COUNT(*)          conta
                FROM   v$log_history
                WHERE  first_time >= TRUNC(SYSDATE) - 7
                       AND first_time < TRUNC(SYSDATE)
                GROUP  BY TRUNC(first_time)),
               v$log)                                                           AS redo_gb_per_day,
       (SELECT COUNT(1)
        FROM   gv$instance)                                                     AS rac_dbinstaces,
       (SELECT value
        FROM   nls_database_parameters a
        WHERE  a.parameter = 'NLS_LANGUAGE')
       || '_'
       || (SELECT value
           FROM   nls_database_parameters a
           WHERE  a.parameter = 'NLS_TERRITORY')
       || '.'
       || (SELECT value
           FROM   nls_database_parameters a
           WHERE  a.parameter = 'NLS_CHARACTERSET')                             AS characterset,
       (SELECT platform_name
        FROM   v$database)                                                      AS platform_name,
       (SELECT TO_CHAR(startup_time, 'mm/dd/rr hh24:mi:ss')
        FROM   v$instance)                                                      AS startup_time,
       (SELECT COUNT(1)
        FROM   dba_users
        WHERE  username NOT IN (SELECT name
                                FROM   SYSTEM.logstdby$skip_support
                                WHERE  action = 0))                             AS user_schemas,
       (SELECT TRUNC(SUM(bytes / 1024 / 1024))
        FROM   v$sgastat
        WHERE  name = 'buffer_cache')                                           buffer_cache_mb,
       (SELECT TRUNC(SUM(bytes / 1024 / 1024))
        FROM   v$sgastat
        WHERE  pool = 'shared pool')                                            shared_pool_mb,
       (SELECT ROUND(value / 1024 / 1024, 0)
        FROM   v$pgastat
        WHERE  name = 'total PGA allocated')                                    AS total_pga_allocated_mb,
       (SELECT ( TRUNC(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   dba_data_files)                                                  db_size_allocated_gb,
       (SELECT ( TRUNC(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   dba_segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' ))                                AS db_size_in_use_gb,
       (SELECT ( TRUNC(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   dba_segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' )
               AND ( owner, segment_name ) IN (SELECT owner,
                                                      table_name
                                               FROM   dba_tab_columns
                                               WHERE  data_type LIKE '%LONG%')) AS db_long_size_gb,
       (SELECT database_role
        FROM   v$database)                                                      AS dg_database_role,
       (SELECT protection_mode
        FROM   v$database)                                                      AS dg_protection_mode,
       (SELECT protection_level
        FROM   v$database)                                                      AS dg_protection_level
FROM   dual; 

spool off

set lines 300

spool opdb__dbinstances__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       inst_id,
       instance_name,
       host_name,
       version,
       status,
       database_status,
       instance_role
FROM   gv$instance; 

spool off

spool opdb__usedspacedetails__&v_host..&v_dbname..&v_inst..&v_hora..log

col OWNER for a30
col TABLESPACE_NAME for a20
set lines 340

-- Column INMEMORY removed.
-- Not exists in 11g
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT owner,
               segment_type,
               tablespace_name,
               flash_cache,
               GROUPING(owner)                           IN_OWNER,
               GROUPING(segment_type)                    IN_SEGMENT_TYPE,
               GROUPING(tablespace_name)                 IN_TABLESPACE_NAME,
               GROUPING(flash_cache)                     IN_FLASH_CACHE,
               ROUND(SUM(bytes) / 1024 / 1024 / 1024, 0) GB
        FROM   dba_segments
        WHERE  owner NOT IN 
                            (
                            SELECT name
                            FROM   SYSTEM.logstdby$skip_support
                            WHERE  action=0)
        GROUP  BY grouping sets( ( ), ( owner ), ( segment_type ),
                    ( tablespace_name ), ( flash_cache ), ( owner, flash_cache ) )) a; 


spool off


set underline off
spool opdb__compressbytable__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT owner,
               SUM(table_count)                  tab,
               TRUNC(SUM(table_gbytes))          table_gb,
               SUM(partition_count)              part,
               TRUNC(SUM(partition_gbytes))      part_gb,
               SUM(subpartition_count)           subpart,
               TRUNC(SUM(subpartition_gbytes))   subpart_gb,
               TRUNC(SUM(table_gbytes) + SUM(partition_gbytes)
                     + SUM(subpartition_gbytes)) total_gbytes
        FROM   (SELECT t.owner,
                       COUNT(*)                        table_count,
                       SUM(bytes / 1024 / 1024 / 1024) table_gbytes,
                       0                               partition_count,
                       0                               partition_gbytes,
                       0                               subpartition_count,
                       0                               subpartition_gbytes
                FROM   dba_tables t,
                       dba_segments s
                WHERE  t.owner = s.owner
                       AND t.table_name = s.segment_name
                       AND s.partition_name IS NULL
                       AND compression = 'ENABLED'
                       AND t.owner NOT IN 
                                          (
                                          SELECT name
                                          FROM   SYSTEM.logstdby$skip_support
                                          WHERE  action=0)
                GROUP  BY t.owner
                UNION ALL
                SELECT t.table_owner owner,
                       0,
                       0,
                       COUNT(*),
                       SUM(bytes / 1024 / 1024 / 1024),
                       0,
                       0
                FROM   dba_tab_partitions t,
                       dba_segments s
                WHERE  t.table_owner = s.owner
                       AND t.table_name = s.segment_name
                       AND t.partition_name = s.partition_name
                       AND compression = 'ENABLED'
                       AND t.table_owner NOT IN (
                                                 SELECT name
                                                 FROM   SYSTEM.logstdby$skip_support
                                                 WHERE  action=0)
                GROUP  BY t.table_owner
                UNION ALL
                SELECT t.table_owner owner,
                       0,
                       0,
                       0,
                       0,
                       COUNT(*),
                       SUM(bytes / 1024 / 1024 / 1024)
                FROM   dba_tab_subpartitions t,
                       dba_segments s
                WHERE  t.table_owner = s.owner
                       AND t.table_name = s.segment_name
                       AND t.subpartition_name = s.partition_name
                       AND compression = 'ENABLED'
                       AND t.table_owner NOT IN 
                                                 (
                                                 SELECT name
                                                 FROM   SYSTEM.logstdby$skip_support
                                                 WHERE  action=0)
                GROUP  BY t.table_owner)
        GROUP  BY owner
        HAVING TRUNC(SUM(table_gbytes) + SUM(partition_gbytes)
                     + SUM(subpartition_gbytes)) > 0) a
ORDER  BY 9 DESC; 

spool off

spool opdb__compressbytype__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT owner,
               TRUNC(SUM(DECODE(compress_for, 'BASIC', gbytes,
                                              0))) basic,
               TRUNC(SUM(DECODE(compress_for, 'OLTP', gbytes,
                                              'ADVANCED', gbytes,
                                              0))) oltp,
               TRUNC(SUM(DECODE(compress_for, 'QUERY LOW', gbytes,
                                              0))) query_low,
               TRUNC(SUM(DECODE(compress_for, 'QUERY HIGH', gbytes,
                                              0))) query_high,
               TRUNC(SUM(DECODE(compress_for, 'ARCHIVE LOW', gbytes,
                                              0))) archive_low,
               TRUNC(SUM(DECODE(compress_for, 'ARCHIVE HIGH', gbytes,
                                              0))) archive_high,
               TRUNC(SUM(gbytes))                  total_gb
        FROM   (SELECT t.owner,
                       t.compress_for,
                       SUM(bytes / 1024 / 1024 / 1024) gbytes
                FROM   dba_tables t,
                       dba_segments s
                WHERE  t.owner = s.owner
                       AND t.table_name = s.segment_name
                       AND s.partition_name IS NULL
                       AND compression = 'ENABLED'
                       AND t.owner NOT IN 
                                          (
                                          SELECT name
                                          FROM   SYSTEM.logstdby$skip_support
                                          WHERE  action=0)
                GROUP  BY t.owner,
                          t.compress_for
                UNION ALL
                SELECT t.table_owner,
                       t.compress_for,
                       SUM(bytes / 1024 / 1024 / 1024) gbytes
                FROM   dba_tab_partitions t,
                       dba_segments s
                WHERE  t.table_owner = s.owner
                       AND t.table_name = s.segment_name
                       AND t.partition_name = s.partition_name
                       AND compression = 'ENABLED'
                       AND t.table_owner NOT IN 
                                                 (
                                                 SELECT name
                                                 FROM   SYSTEM.logstdby$skip_support
                                                 WHERE  action=0)
                GROUP  BY t.table_owner,
                          t.compress_for
                UNION ALL
                SELECT t.table_owner,
                       t.compress_for,
                       SUM(bytes / 1024 / 1024 / 1024) gbytes
                FROM   dba_tab_subpartitions t,
                       dba_segments s
                WHERE  t.table_owner = s.owner
                       AND t.table_name = s.segment_name
                       AND t.subpartition_name = s.partition_name
                       AND compression = 'ENABLED'
                       AND t.table_owner NOT IN 
                                                 (
                                                 SELECT name
                                                 FROM   SYSTEM.logstdby$skip_support
                                                 WHERE  action=0)
                GROUP  BY t.table_owner,
                          t.compress_for)
        GROUP  BY owner
        HAVING TRUNC(SUM(gbytes)) > 0) a
ORDER  BY total_gb DESC; 

spool off
clear break
clear compute


spool opdb__spacebyownersegtype__&v_host..&v_dbname..&v_inst..&v_hora..log

column owner format a30
column segment_type format a30

SET pages 100
--break on report
--compute sum of total_gb on report

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT a.owner,
               DECODE(a.segment_type, 'TABLE', 'TABLE',
                                      'TABLE PARTITION', 'TABLE',
                                      'TABLE SUBPARTITION', 'TABLE',
                                      'INDEX', 'INDEX',
                                      'INDEX PARTITION', 'INDEX',
                                      'INDEX SUBPARTITION', 'INDEX',
                                      'LOB', 'LOB',
                                      'LOB PARTITION', 'LOB',
                                      'LOBSEGMENT', 'LOB',
                                      'LOBINDEX', 'LOB',
                                      'OTHERS')         segment_type,
               TRUNC(SUM(a.bytes) / 1024 / 1024 / 1024) total_gb
        FROM   dba_segments a
        WHERE  a.owner NOT IN 
                            (
                            SELECT name
                            FROM   SYSTEM.logstdby$skip_support
                            WHERE  action=0)
        GROUP  BY a.owner,
                  DECODE(a.segment_type, 'TABLE', 'TABLE',
                                         'TABLE PARTITION', 'TABLE',
                                         'TABLE SUBPARTITION', 'TABLE',
                                         'INDEX', 'INDEX',
                                         'INDEX PARTITION', 'INDEX',
                                         'INDEX SUBPARTITION', 'INDEX',
                                         'LOB', 'LOB',
                                         'LOB PARTITION', 'LOB',
                                         'LOBSEGMENT', 'LOB',
                                         'LOBINDEX', 'LOB',
                                         'OTHERS')
        HAVING TRUNC(SUM(a.bytes) / 1024 / 1024 / 1024) >= 1) a
ORDER  BY total_gb DESC; 


spool off

col tablespace_name FOR a35
col extent_management FOR a20
col allocation_type FOR a10
col segment_space_management FOR a20

spool opdb__spacebytablespace__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT b.tablespace_name,
               b.extent_management,
               b.allocation_type,
               b.segment_space_management,
               SUM(estd_ganho_mb) estd_ganho_mb
        FROM   (SELECT b.tablespace_name,
                       b.extent_management,
                       b.allocation_type,
                       b.segment_space_management,
                       a.initial_extent / 1024                                                                                        inital_kb,
                       a.owner,
                       a.segment_name,
                       a.partition_name,
                       ( a.bytes ) / 1024                                                                                             segsize_kb,
                       TRUNC(( a.initial_extent / 1024 ) / ( ( a.bytes ) / 1024 ) * 100)                                              perc,
                       TRUNC(( ( a.bytes ) / 1024 / 100 ) * TRUNC(( a.initial_extent / 1024 ) / ( ( a.bytes ) / 1024 ) * 100) / 1024) estd_ganho_mb
                FROM   dba_segments a
                       inner join dba_tablespaces b
                               ON a.tablespace_name = b.tablespace_name
                WHERE  a.owner NOT IN 
                                   (
                                   SELECT name
                                   FROM   SYSTEM.logstdby$skip_support
                                   WHERE  action=0)
                       AND b.allocation_type = 'SYSTEM'
                       AND a.initial_extent = a.bytes) b
        GROUP  BY b.tablespace_name,
                  b.extent_management,
                  b.allocation_type,
                  b.segment_space_management
        UNION ALL
        SELECT b.tablespace_name,
               b.extent_management,
               b.allocation_type,
               b.segment_space_management,
               SUM(estd_ganho_mb) estd_ganho_mb
        FROM   (SELECT b.tablespace_name,
                       b.extent_management,
                       b.allocation_type,
                       b.segment_space_management,
                       a.initial_extent / 1024                                                                                        inital_kb,
                       a.owner,
                       a.segment_name,
                       a.partition_name,
                       ( a.bytes ) / 1024                                                                                             segsize_kb,
                       TRUNC(( a.initial_extent / 1024 ) / ( ( a.bytes ) / 1024 ) * 100)                                              perc,
                       TRUNC(( ( a.bytes ) / 1024 / 100 ) * TRUNC(( a.initial_extent / 1024 ) / ( ( a.bytes ) / 1024 ) * 100) / 1024) estd_ganho_mb
                FROM   dba_segments a
                       inner join dba_tablespaces b
                               ON a.tablespace_name = b.tablespace_name
                WHERE  a.owner NOT IN 
                                   (
                                   SELECT name
                                   FROM   SYSTEM.logstdby$skip_support
                                   WHERE  action=0)
                       AND b.allocation_type != 'SYSTEM') b
        GROUP  BY b.tablespace_name,
                  b.extent_management,
                  b.allocation_type,
                  b.segment_space_management) a; 

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

spool opdb__freespaces__&v_host..&v_dbname..&v_inst..&v_hora..log

column tablespace format a30
column pct_used format 999.99
column graph format a25 heading "GRAPH (X=5%)"
column status format a10
set lines 300 pages 100

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT total.ts                                                                          tablespace,
               DECODE(total.mb, NULL, 'OFFLINE',
                                dbat.status)                                                     status,
               TRUNC(total.mb / 1024)                                                            total_gb,
               TRUNC(NVL(total.mb - free.mb, total.mb) / 1024)                                   used_gb,
               TRUNC(NVL(free.mb, 0) / 1024)                                                     free_gb,
               DECODE(total.mb, NULL, 0,
                                NVL(ROUND(( total.mb - free.mb ) / ( total.mb ) * 100, 2), 100)) pct_used,
               CASE
                 WHEN ( total.mb IS NULL ) THEN '['
                                                || RPAD(LPAD('OFFLINE', 13, '-'), 20, '-')
                                                ||']'
                 ELSE '['
                      || DECODE(free.mb, NULL, 'XXXXXXXXXXXXXXXXXXXX',
                                         NVL(RPAD(LPAD('X', TRUNC(( 100 - ROUND(( free.mb ) / ( total.mb ) * 100, 2) ) / 5), 'X'), 20, '-'), '--------------------'))
                      ||']'
               END                                                                               AS GRAPH
        FROM   (SELECT tablespace_name          ts,
                       SUM(bytes) / 1024 / 1024 mb
                FROM   dba_data_files
                GROUP  BY tablespace_name) total,
               (SELECT tablespace_name          ts,
                       SUM(bytes) / 1024 / 1024 mb
                FROM   dba_free_space
                GROUP  BY tablespace_name) free,
               dba_tablespaces dbat
        WHERE  total.ts = free.ts(+)
               AND total.ts = dbat.tablespace_name
        UNION ALL
        SELECT sh.tablespace_name,
               'TEMP',
               SUM(sh.bytes_used + sh.bytes_free) / 1024 / 1024                        total_mb,
               SUM(sh.bytes_used) / 1024 / 1024                                        used_mb,
               SUM(sh.bytes_free) / 1024 / 1024                                        free_mb,
               ROUND(SUM(sh.bytes_used) / SUM(sh.bytes_used + sh.bytes_free) * 100, 2) pct_used,
               '['
               ||DECODE(SUM(sh.bytes_free), 0, 'XXXXXXXXXXXXXXXXXXXX',
                                            NVL(RPAD(LPAD('X', ( TRUNC(ROUND(( SUM(sh.bytes_used) / SUM(sh.bytes_used + sh.bytes_free) ) * 100, 2) / 5) ), 'X'), 20, '-'),
                                            '--------------------'))
               ||']'
        FROM   v$temp_space_header sh
        GROUP  BY tablespace_name) a
ORDER  BY graph; 


spool off 



set pages 9000 

spool opdb__dblinks__&v_host..&v_dbname..&v_inst..&v_hora..log

col owner for a20
col DB_LINK for a50
col USERNAME for a20
col HOST for a30
set lines 340

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       owner,
       db_link,
       host,
       created
FROM   dba_db_links
WHERE  owner NOT IN 
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0);

spool off

col name for a80
col value for a60
col DEFAULT_VALUE for a30
col ISDEFAULT for a6
set lines 300
-- Column DEFAULT_VALUE removed.
-- Not exists in 11g

spool opdb__dbparameters__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                   AS pkey,
       inst_id,
       REPLACE(name, ',', '/')                         name,
       REPLACE(SUBSTR(value, 1, 60), ',', '/')         value,
       isdefault
FROM   gv$parameter
ORDER  BY 2; 

spool off

spool opdb__dbfeatures__&v_host..&v_dbname..&v_inst..&v_hora..log

set lines 320 
col name for a70
col feature_info for a76

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                 AS pkey,
       REPLACE(name, ',', '/')                       name,
       currently_used,
       detected_usages,
       total_samples,
       TO_CHAR(first_usage_date, 'MM/DD/YY HH24:MI') first_usage,
       TO_CHAR(last_usage_date, 'MM/DD/YY HH24:MI')  last_usage,
       aux_count
FROM   dba_feature_usage_statistics
ORDER  BY name; 

spool off

spool opdb__dbhwmarkstatistics__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       description,
       highwater,
       last_value
FROM   dba_high_water_mark_statistics
ORDER  BY description; 

spool off

spool opdb__cpucoresusage__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
       TO_CHAR(timestamp, 'MM/DD/YY HH24:MI') dt,
       cpu_count,
       cpu_core_count,
       cpu_socket_count
FROM   dba_cpu_usage_statistics
ORDER  BY timestamp; 

spool off

col object_type for a20
col owner for a40

spool opdb__dbobjects__&v_host..&v_dbname..&v_inst..&v_hora..log

-- Column EDITIONABLE removed.
-- Not exists in 11g

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       a.*
FROM   (SELECT owner,
               object_type,
               COUNT(1)              count,
               GROUPING(owner)       in_owner,
               GROUPING(object_type) in_OBJECT_TYPE
        FROM   dba_objects
        WHERE  owner NOT IN 
                            (
                            SELECT name
                            FROM   SYSTEM.logstdby$skip_support
                            WHERE  action=0)
        GROUP  BY grouping sets ( ( object_type ), 
		                          ( owner, object_type ) )) a; 

spool off

col OWNER for a30
col NAME for a40
col TYPE for a40
set lines 400

spool opdb__sourcecode__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT pkey,
       owner,
       TYPE,
       SUM(nr_lines)       sum_nr_lines,
       COUNT(1)            qt_objs,
       SUM(count_utl)      sum_nr_lines_w_utl,
       SUM(count_dbms)     sum_nr_lines_w_dbms,
       SUM(count_exec_im)  count_exec_im,
       SUM(count_dbms_sql) count_dbms_sql,
       SUM(count_dbms_utl) sum_nr_lines_w_dbms_utl,
       SUM(count_total)    sum_count_total
FROM   (SELECT '&&v_host'
               || '_'
               || '&&v_dbname'
               || '_'
               || '&&v_hora' AS pkey,
               owner,
               name,
               TYPE,
               MAX(line)     NR_LINES,
               COUNT(CASE
                       WHEN LOWER(text) LIKE '%utl_%' THEN 1
                     END)    count_utl,
               COUNT(CASE
                       WHEN LOWER(text) LIKE '%dbms_%' THEN 1
                     END)    count_dbms,
               COUNT(CASE
                       WHEN LOWER(text) LIKE '%dbms_%'
                            AND LOWER(text) LIKE '%utl_%' THEN 1
                     END)    count_dbms_utl,
               COUNT(CASE
                       WHEN LOWER(text) LIKE '%execute%immediate%' THEN 1
                     END)    count_exec_im,
               COUNT(CASE
                       WHEN LOWER(text) LIKE '%dbms_sql%' THEN 1
                     END)    count_dbms_sql,
               COUNT(1)      count_total
        FROM   dba_source
        WHERE  owner NOT IN 
                            (
                            SELECT name
                            FROM   SYSTEM.logstdby$skip_support
                            WHERE  action=0)
        GROUP  BY '&&v_host'
                  || '_'
                  || '&&v_dbname'
                  || '_'
                  || '&&v_hora',
                  owner,
                  name,
                  TYPE)
GROUP  BY pkey,
          owner,
          TYPE; 

spool off



spool opdb__partsubparttypes__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       owner,
       partitioning_type,
       subpartitioning_type,
       COUNT(1)
FROM   dba_part_tables
WHERE  owner NOT IN 
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          owner,
          partitioning_type,
          subpartitioning_type; 

spool off

spool opdb__indexestypes__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       owner,
       index_type,
       COUNT(1)
FROM   dba_indexes
WHERE  owner NOT IN 
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          owner,
          index_type; 

spool off

col owner for a50
col data_type for a60

spool opdb__datatypes__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       owner,
       data_type,
       COUNT(1)
FROM   dba_tab_columns
WHERE  owner NOT IN 
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          owner,
          data_type; 

spool off

spool opdb__tablesnopk__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'              AS pkey,
       owner,
       SUM(pk)                    pk,
       SUM(uk)                    uk,
       SUM(ck)                    ck,
       SUM(ri)                    ri,
       SUM(vwck)                  vwck,
       SUM(vwro)                  vwro,
       SUM(hashexpr)              hashexpr,
       SUM(suplog)                suplog,
       COUNT(DISTINCT table_name) num_tables,
       COUNT(1)                   total_cons
FROM   (SELECT a.owner,
               a.table_name,
               DECODE(b.constraint_type, 'P', 1,
                                         NULL) pk,
               DECODE(b.constraint_type, 'U', 1,
                                         NULL) uk,
               DECODE(b.constraint_type, 'C', 1,
                                         NULL) ck,
               DECODE(b.constraint_type, 'R', 1,
                                         NULL) ri,
               DECODE(b.constraint_type, 'V', 1,
                                         NULL) vwck,
               DECODE(b.constraint_type, 'O', 1,
                                         NULL) vwro,
               DECODE(b.constraint_type, 'H', 1,
                                         NULL) hashexpr,
               DECODE(b.constraint_type, 'F', 1,
                                         NULL) refcolcons,
               DECODE(b.constraint_type, 'S', 1,
                                         NULL) suplog
        FROM   dba_tables a
               left outer join dba_constraints b
                            ON a.owner = b.owner
                               AND a.table_name = b.table_name)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          owner; 

spool off

spool opdb__systemstats__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       sname,
       pname,
       pval1,
       pval2
FROM   sys.aux_stats$; 

spool off

col Comments for a60

spool opdb__patchlevel__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                            AS pkey,
       TO_CHAR(action_time, 'mm/dd/rr hh24:mi') AS "Time",
       action                                   AS "Action",
       namespace                                AS "Namespace",
       version                                  AS "Version",
       id                                       AS "ID",
       comments                                 AS "Comments"
FROM   sys.registry$history
ORDER  BY action_time; 

spool off

column min_snapid new_value v_min_snapid noprint
column max_snapid new_value v_max_snapid noprint
column total_secs new_value v_total_secs noprint

SELECT MIN(snap_id)
       min_snapid,
       MAX(snap_id)
       max_snapid,
       ( TO_NUMBER(CAST(MAX(end_interval_time) AS DATE) - CAST(
                     MIN(begin_interval_time) AS DATE)) * 60 * 60 * 24 )
       total_secs
FROM   dba_hist_snapshot
WHERE  begin_interval_time > ( SYSDATE - 30 )
/ 


col MESSAGE_TIME for a25
col message_text for a200
col host_id for a50
col component_id for a15
col message_id for a30
col message_group for a35
col container_name for a40

spool opdb__alertlog__&v_host..&v_dbname..&v_inst..&v_hora..log

-- ORA-00600 [17147] ORA-48216 When Querying V$DIAG_ALERT_EXT View (Doc ID 2119059.1)
-- Order By removed because of Unpublished Bug 21266522 - (this issue only exists in 11.2.0.4)
SELECT *
FROM   (SELECT TO_CHAR(A.originating_timestamp, 'dd/mm/yyyy hh24:mi:ss')               MESSAGE_TIME,
               REPLACE(REPLACE(SUBSTR(a.message_text, 0, 180), ',', ';'), '\n', '   ') message_text,
               SUBSTR(a.host_id, 0, 30)                                                host_id,
               SUBSTR(a.component_id, 0, 30)                                           component_id,
               a.message_type,
               a.message_level,
               SUBSTR(a.message_id, 0, 30)                                             message_id,
               a.message_group
        FROM   v$diag_alert_ext A)
WHERE  ROWNUM < 5001;

spool off

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


spool opdb__awrhistsysmetrichist__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                            AS pkey,
       hsm.dbid,
       hsm.instance_number,
       TO_CHAR(hsm.begin_time, 'hh24')          hour,
       hsm.metric_name,
       hsm.metric_unit,--dhsnap.STARTUP_TIME,
       AVG(hsm.value)                           avg_value,
       STATS_MODE(hsm.value)                    mode_value,
       MEDIAN(hsm.value)                        median_value,
       MIN(hsm.value)                           min_value,
       MAX(hsm.value)                           max_value,
       SUM(hsm.value)                           sum_value,
       PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY hsm.value DESC) AS "PERC50",
       PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY hsm.value DESC) AS "PERC75",
       PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY hsm.value DESC) AS "PERC90",
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY hsm.value DESC) AS "PERC95",
       PERCENTILE_CONT(0)
         within GROUP (ORDER BY hsm.value DESC) AS "PERC100"
FROM   dba_hist_sysmetric_history hsm
       inner join dba_hist_snapshot dhsnap
               ON hsm.snap_id = dhsnap.snap_id
                  AND hsm.instance_number = dhsnap.instance_number
                  AND hsm.dbid = dhsnap.dbid
WHERE  hsm.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          hsm.dbid,
          hsm.instance_number,
          TO_CHAR(hsm.begin_time, 'hh24'),
          hsm.metric_name,
          hsm.metric_unit--, dhsnap.STARTUP_TIME
ORDER  BY hsm.dbid,
          hsm.instance_number,
          hsm.metric_name,
          TO_CHAR(hsm.begin_time, 'hh24'); 

spool off


spool opdb__awrhistosstat__&v_host..&v_dbname..&v_inst..&v_hora..log

WITH v_osstat_all
     AS (SELECT os.dbid,
                os.instance_number,
                TO_CHAR(snap.begin_interval_time, 'hh24')
                   hh24,
                os.stat_name,
                value,
                ( TO_NUMBER(CAST(end_interval_time AS DATE) - CAST(begin_interval_time AS DATE)) * 60 * 60 * 24 )
                   snap_total_secs,
                PERCENTILE_CONT(0.5)
                  within GROUP (ORDER BY value DESC) over (
                    PARTITION BY os.dbid, os.instance_number,
                  TO_CHAR(snap.begin_interval_time, 'hh24'), os.stat_name) AS
                "PERC50",
                PERCENTILE_CONT(0.25)
                  within GROUP (ORDER BY value DESC) over (
                    PARTITION BY os.dbid, os.instance_number,
                  TO_CHAR(snap.begin_interval_time, 'hh24'), os.stat_name) AS
                "PERC75",
                PERCENTILE_CONT(0.1)
                  within GROUP (ORDER BY value DESC) over (
                    PARTITION BY os.dbid, os.instance_number,
                  TO_CHAR(snap.begin_interval_time, 'hh24'), os.stat_name) AS
                "PERC90",
                PERCENTILE_CONT(0.05)
                  within GROUP (ORDER BY value DESC) over (
                    PARTITION BY os.dbid, os.instance_number,
                  TO_CHAR(snap.begin_interval_time, 'hh24'), os.stat_name) AS
                "PERC95",
                PERCENTILE_CONT(0)
                  within GROUP (ORDER BY value DESC) over (
                    PARTITION BY os.dbid, os.instance_number,
                  TO_CHAR(snap.begin_interval_time, 'hh24'), os.stat_name) AS
                "PERC100"
         FROM   dba_hist_osstat os
                inner join dba_hist_snapshot snap
                        ON os.snap_id = snap.snap_id
         WHERE  os.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid')
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'        AS pkey,
       '&&v_total_secs'     total_awr_secs,
       dbid,
       instance_number,
       hh24,
       stat_name,
       SUM(snap_total_secs) hh24_total_secs,
       AVG(value)           avg_value,
       STATS_MODE(value)    mode_value,
       MEDIAN(value)        median_value,
       AVG(perc50)          PERC50,
       AVG(perc75)          PERC75,
       AVG(perc90)          PERC90,
       AVG(perc95)          PERC95,
       AVG(perc100)         PERC100,
       MIN(value)           min_value,
       MAX(value)           max_value,
       SUM(value)           sum_value,
       COUNT(1)             count
FROM   v_osstat_all
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          '&&v_total_secs',
          dbid,
          instance_number,
          hh24,
          stat_name; 

spool off

set pages 50000

spool opdb__awrhistcmdtypes__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
       TO_CHAR(c.begin_interval_time, 'hh24') hh24,
       b.command_type,
       COUNT(1)                               coun,
       AVG(buffer_gets_delta)                 AVG_BUFFER_GETS,
       AVG(elapsed_time_delta)                AVG_ELASPED_TIME,
       AVG(rows_processed_delta)              AVG_ROWS_PROCESSED,
       AVG(executions_delta)                  AVG_EXECUTIONS,
       AVG(cpu_time_delta)                    AVG_CPU_TIME,
       AVG(iowait_delta)                      AVG_IOWAIT,
       AVG(clwait_delta)                      AVG_CLWAIT,
       AVG(apwait_delta)                      AVG_APWAIT,
       AVG(ccwait_delta)                      AVG_CCWAIT,
       AVG(plsexec_time_delta)                AVG_PLSEXEC_TIME
FROM   dba_hist_sqlstat a
       inner join dba_hist_sqltext b
               ON ( a.sql_id = b.sql_id )
       inner join dba_hist_snapshot c
               ON ( a.snap_id = c.snap_id )
WHERE  a.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          TO_CHAR(c.begin_interval_time, 'hh24'),
          b.command_type; 

spool off


set lines 2000 pages 9999
col SERVICE_ID format 999999999
col NAME format A30
col CREATION_DATE format A30
col NETWORK_NAME format A45
col FAILOVER_METHOD format A30
col FAILOVER_TYPE format A30

spool opdb__dbservicesinfo__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT service_id,
       name service_name,
       network_name,
       TO_CHAR(creation_date, 'dd/mm/yyyy hh24:mi:ss') creation_date,
       failover_method,
       failover_type,
       failover_retries,
       failover_delay,
       goal
FROM dba_services 
ORDER BY NAME;

spool off

col owner format a40
col segment_name format a40
col segment_type format a20
col tablespace_name format a40

spool opdb__usrsegatt__&v_host..&v_dbname..&v_inst..&v_hora..log

SELECT owner,
       segment_name,
       segment_type,
       tablespace_name
FROM dba_segments
WHERE tablespace_name IN ('SYS', 'SYSTEM')
AND owner NOT IN
(SELECT name
 FROM system.logstdby$skip_support
 WHERE action=0);

spool off