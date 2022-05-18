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

This script access Automatic Repository Workload (AWR) views in the database dictionary.
Please ensure you have proper licensing. For more information consult Oracle Support Doc ID 1490798.1

*/


/*

Version: 2.0.5
Date: 2022-04-22

*/

define version = '2.0.5'
define dtrange = 30
define colspr = ';'

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
set term on
set pause off
set wrap on
set echo off
set appinfo 'OPTIMUS_PRIME'

whenever sqlerror continue
whenever oserror continue

column instnc new_value v_inst noprint
column hostnc new_value v_host noprint
column horanc new_value v_hora noprint
column dbname new_value v_dbname noprint
column dbversion new_value v_dbversion noprint
column min_snapid new_value v_min_snapid noprint
column max_snapid new_value v_max_snapid noprint
column dbid new_value v_dbid noprint

SELECT host_name     hostnc,
       instance_name instnc
FROM   v$instance
/

SELECT name dbname
FROM   v$database
/

SELECT TO_CHAR(SYSDATE, 'mmddrrhh24miss') horanc
FROM   dual
/

SELECT substr(replace(version,'.',''),0,3) dbversion
from v$instance
/

SELECT dbid dbid
FROM   v$database
/

SELECT MIN(snap_id) min_snapid,
       MAX(snap_id) max_snapid
FROM   dba_hist_snapshot
WHERE  begin_interval_time > ( SYSDATE - '&&dtrange' )
AND dbid = '&&v_dbid'
/

define v_tag = &v_dbversion._&version._&v_host..&v_dbname..&v_inst..&v_hora..log

spool opdb__awrsnapdetails__&v_tag

WITH vawrsnap as (
SELECT  '&&v_host'
        || '_'
        || '&&v_dbname'
        || '_'
        || '&&v_hora'                                                            AS pkey,
        dbid, instance_number, hour,
        min(snap_id) min_snapid, max(snap_id) max_snapid,
        min(begin_interval_time) min_begin_interval_time, max(begin_interval_time) max_begin_interval_time,
        count(1) cnt,ROUND(SUM(snaps_diff_secs),0) sum_snaps_diff_secs,
        ROUND(avg(snaps_diff_secs),0) avg_snaps_diff_secs,
        ROUND(median(snaps_diff_secs),0) median_snaps_diff_secs,
        ROUND(STATS_MODE(snaps_diff_secs),0) mode_snaps_diff_secs,
        ROUND(min(snaps_diff_secs),0) min_snaps_diff_secs,
        ROUND(max(snaps_diff_secs),0) max_snaps_diff_secs
FROM (
SELECT
       s.snap_id,
       s.dbid,
       s.instance_number,
       s.begin_interval_time,
       s.end_interval_time,
       TO_CHAR(s.begin_interval_time,'hh24') hour,
       ( TO_NUMBER(CAST((end_interval_time) AS DATE) - CAST(
                     (begin_interval_time) AS DATE)) * 60 * 60 * 24 ) snaps_diff_secs
FROM   dba_hist_snapshot s
WHERE  s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND dbid = '&&v_dbid'
)
GROUP BY '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora', dbid, instance_number, hour)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || min_snapid || '&&colspr' || max_snapid || '&&colspr' || min_begin_interval_time || '&&colspr' ||
       max_begin_interval_time || '&&colspr' || cnt || '&&colspr' || sum_snaps_diff_secs || '&&colspr' || avg_snaps_diff_secs || '&&colspr' || median_snaps_diff_secs || '&&colspr' ||
       mode_snaps_diff_secs || '&&colspr' || min_snaps_diff_secs || '&&colspr' || max_snaps_diff_secs
FROM vawrsnap;

spool off

spool opdb__opkeylog__&v_tag

with vop as (
select '&&v_tag' pkey, '&&version' opscriptversion, '&&v_dbversion' dbversion, '&&v_host' hostname,
'&&v_dbname' dbname, '&&v_inst' instance_name, '&&v_hora' collection_time, '&&v_dbid' dbid, null "CMNT"
from dual)
select pkey || '&&colspr' || opscriptversion || '&&colspr' || dbversion || '&&colspr' || hostname
       || '&&colspr' || dbname || '&&colspr' || instance_name || '&&colspr' || collection_time || '&&colspr' || dbid || '&&colspr' || CMNT
from vop;

spool off

spool opdb__dbsummary__&v_tag

WITH vdbsummary AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                                            AS pkey,
       (SELECT dbid
        FROM   v$database)                                                      AS dbid,
       (SELECT name
        FROM   v$database)                                                      AS db_name,
       (SELECT cdb
        FROM   v$database)                                                      AS cdb,
       (SELECT version
        FROM   v$instance)                                                      AS dbversion,
       (SELECT banner
        FROM   v$version
        WHERE  ROWNUM < 2)                                                      AS dbfullversion,
       (SELECT log_mode
        FROM   v$database)                                                      AS log_mode,
       (SELECT force_logging
        FROM   v$database)                                                      AS force_logging,
       (SELECT ( ROUND(AVG(conta) * AVG(bytes) / 1024 / 1024 / 1024) )
        FROM   (SELECT TRUNC(first_time) dia,
                       COUNT(*)          conta
                FROM   v$log_history
                WHERE  first_time >= TRUNC(SYSDATE) - '&&dtrange'
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
        FROM   cdb_users
        WHERE  username NOT IN (SELECT name
                                FROM   SYSTEM.logstdby$skip_support
                                WHERE  action = 0))                             AS user_schemas,
       (SELECT ROUND(SUM(bytes / 1024 / 1024))
        FROM   v$sgastat
        WHERE  name = 'buffer_cache')                                           buffer_cache_mb,
       (SELECT ROUND(SUM(bytes / 1024 / 1024))
        FROM   v$sgastat
        WHERE  pool = 'shared pool')                                            shared_pool_mb,
       (SELECT ROUND(value / 1024 / 1024, 0)
        FROM   v$pgastat
        WHERE  name = 'total PGA allocated')                                    AS total_pga_allocated_mb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   cdb_data_files)                                                  db_size_allocated_gb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   cdb_segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' ))                                AS db_size_in_use_gb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   cdb_segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' )
               AND ( owner, segment_name ) IN (SELECT owner,
                                                      table_name
                                               FROM   cdb_tab_columns
                                               WHERE  data_type LIKE '%LONG%')) AS db_long_size_gb,
       (SELECT database_role
        FROM   v$database)                                                      AS dg_database_role,
       (SELECT protection_mode
        FROM   v$database)                                                      AS dg_protection_mode,
       (SELECT protection_level
        FROM   v$database)                                                      AS dg_protection_level
FROM   dual)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || db_name || '&&colspr' || cdb || '&&colspr' || dbversion || '&&colspr' || dbfullversion || '&&colspr' || log_mode || '&&colspr' || force_logging || '&&colspr' ||
       redo_gb_per_day || '&&colspr' || rac_dbinstaces || '&&colspr' || characterset || '&&colspr' || platform_name || '&&colspr' || startup_time || '&&colspr' || user_schemas || '&&colspr' ||
	   buffer_cache_mb || '&&colspr' || shared_pool_mb || '&&colspr' || total_pga_allocated_mb || '&&colspr' || db_size_allocated_gb || '&&colspr' || db_size_in_use_gb || '&&colspr' ||
	   db_long_size_gb || '&&colspr' || dg_database_role || '&&colspr' || dg_protection_mode || '&&colspr' || dg_protection_level
FROM vdbsummary;

spool off

spool opdb__pdbsinfo__&v_tag

WITH vpdbinfo AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       dbid,
       pdb_id,
       pdb_name,
       status,
       logging
FROM   cdb_pdbs )
SELECT pkey || '&&colspr' || dbid || '&&colspr' || pdb_id || '&&colspr' || pdb_name || '&&colspr' || status || '&&colspr' || logging
FROM  vpdbinfo;

spool off

spool opdb__pdbsopenmode__&v_tag

WITH vpdbmode as (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                   AS pkey,
       con_id,
       name,
       open_mode,
       total_size / 1024 / 1024 / 1024 TOTAL_GB
FROM   v$pdbs )
SELECT pkey || '&&colspr' || con_id || '&&colspr' || name || '&&colspr' || open_mode || '&&colspr' || TOTAL_GB
FROM vpdbmode;

spool off

spool opdb__dbinstances__&v_tag

WITH vdbinst as (
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
FROM   gv$instance )
SELECT pkey || '&&colspr' || inst_id || '&&colspr' || instance_name || '&&colspr' || host_name || '&&colspr' ||
       version || '&&colspr' || status || '&&colspr' || database_status || '&&colspr' || instance_role
FROM vdbinst;

spool off

spool opdb__usedspacedetails__&v_tag

WITH vused AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id,
       owner,
       segment_type,
       ROUND(SUM(bytes) / 1024 / 1024 / 1024, 0) GB
       FROM   cdb_segments
       WHERE  owner NOT IN (
                          SELECT name
                          FROM   SYSTEM.logstdby$skip_support
                          WHERE  action=0)
       GROUP  BY '&&v_host'
              || '_'
              || '&&v_dbname'
              || '_'
              || '&&v_hora',
              con_id, owner, segment_type )
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || segment_type || '&&colspr' || GB
FROM vused;

spool off

spool opdb__compressbytable__&v_tag

WITH vtbcompress AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id,
       owner,
       SUM(table_count)                  tab,
       TRUNC(SUM(table_gbytes))          table_gb,
       SUM(partition_count)              part,
       TRUNC(SUM(partition_gbytes))      part_gb,
       SUM(subpartition_count)           subpart,
       TRUNC(SUM(subpartition_gbytes))   subpart_gb,
       TRUNC(SUM(table_gbytes) + SUM(partition_gbytes)
             + SUM(subpartition_gbytes)) total_gbytes
       FROM   (SELECT t.con_id,
                       t.owner,
                       COUNT(*)                        table_count,
                       SUM(bytes / 1024 / 1024 / 1024) table_gbytes,
                       0                               partition_count,
                       0                               partition_gbytes,
                       0                               subpartition_count,
                       0                               subpartition_gbytes
                FROM   cdb_tables t,
                       cdb_segments s
                WHERE  t.con_id = s.con_id
                       AND t.owner = s.owner
                       AND t.table_name = s.segment_name
                       AND s.partition_name IS NULL
                       AND compression = 'ENABLED'
                       AND t.owner NOT IN
                                          (
                                          SELECT name
                                          FROM   SYSTEM.logstdby$skip_support
                                          WHERE  action=0)
                GROUP  BY t.con_id,
                          t.owner
                UNION ALL
                SELECT t.con_id,
                       t.table_owner owner,
                       0,
                       0,
                       COUNT(*),
                       SUM(bytes / 1024 / 1024 / 1024),
                       0,
                       0
                FROM   cdb_tab_partitions t,
                       cdb_segments s
                WHERE  t.con_id = s.con_id
                       AND t.table_owner = s.owner
                       AND t.table_name = s.segment_name
                       AND t.partition_name = s.partition_name
                       AND compression = 'ENABLED'
                       AND t.table_owner NOT IN (
                                                 SELECT name
                                                 FROM   SYSTEM.logstdby$skip_support
                                                 WHERE  action=0)
                GROUP  BY t.con_id,
                          t.table_owner
                UNION ALL
                SELECT t.con_id,
                       t.table_owner owner,
                       0,
                       0,
                       0,
                       0,
                       COUNT(*),
                       SUM(bytes / 1024 / 1024 / 1024)
                FROM   cdb_tab_subpartitions t,
                       cdb_segments s
                WHERE  t.con_id = s.con_id
                       AND t.table_owner = s.owner
                       AND t.table_name = s.segment_name
                       AND t.subpartition_name = s.partition_name
                       AND compression = 'ENABLED'
                       AND t.table_owner NOT IN
                                                 (
                                                 SELECT name
                                                 FROM   SYSTEM.logstdby$skip_support
                                                 WHERE  action=0)
                GROUP  BY t.con_id,
                          t.table_owner)
        GROUP  BY con_id,
                  owner
        HAVING TRUNC(SUM(table_gbytes) + SUM(partition_gbytes)
                     + SUM(subpartition_gbytes)) > 0 )
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || tab || '&&colspr' || table_gb || '&&colspr' || part || '&&colspr' ||
       part_gb || '&&colspr' || subpart || '&&colspr' || subpart_gb || '&&colspr' || total_gbytes
FROM vtbcompress
ORDER  BY total_gbytes DESC;

spool off

spool opdb__compressbytype__&v_tag

WITH vcompresstype AS (
     SELECT '&&v_host'
            || '_'
            || '&&v_dbname'
            || '_'
            || '&&v_hora' AS pkey,
	        con_id,
            owner,
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
     FROM   (SELECT t.con_id,
                    t.owner,
                    t.compress_for,
                    SUM(bytes / 1024 / 1024 / 1024) gbytes
             FROM   cdb_tables t,
                    cdb_segments s
             WHERE  t.con_id = s.con_id
                    AND t.owner = s.owner
                    AND t.table_name = s.segment_name
                    AND s.partition_name IS NULL
                    AND compression = 'ENABLED'
                    AND t.owner NOT IN
                                       (
                                       SELECT name
                                       FROM   SYSTEM.logstdby$skip_support
                                       WHERE  action=0)
             GROUP  BY t.con_id,
                       t.owner,
                       t.compress_for
             UNION ALL
             SELECT t.con_id,
                    t.table_owner,
                    t.compress_for,
                    SUM(bytes / 1024 / 1024 / 1024) gbytes
             FROM   cdb_tab_partitions t,
                    cdb_segments s
             WHERE  t.con_id = s.con_id
                    AND t.table_owner = s.owner
                    AND t.table_name = s.segment_name
                    AND t.partition_name = s.partition_name
                    AND compression = 'ENABLED'
                    AND t.table_owner NOT IN
                                              (
                                              SELECT name
                                              FROM   SYSTEM.logstdby$skip_support
                                              WHERE  action=0)
             GROUP  BY t.con_id,
                       t.table_owner,
                       t.compress_for
             UNION ALL
             SELECT t.con_id,
                    t.table_owner,
                    t.compress_for,
                    SUM(bytes / 1024 / 1024 / 1024) gbytes
             FROM   cdb_tab_subpartitions t,
                    cdb_segments s
             WHERE  t.con_id = s.con_id
                    AND t.table_owner = s.owner
                    AND t.table_name = s.segment_name
                    AND t.subpartition_name = s.partition_name
                    AND compression = 'ENABLED'
                    AND t.table_owner NOT IN
                                              (
                                              SELECT name
                                              FROM   SYSTEM.logstdby$skip_support
                                              WHERE  action=0)
             GROUP  BY t.con_id,
                       t.table_owner,
                       t.compress_for)
     GROUP  BY con_id,
               owner
     HAVING TRUNC(SUM(gbytes)) > 0)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || basic || '&&colspr' || oltp || '&&colspr' || query_low || '&&colspr' ||
       query_high || '&&colspr' || archive_low || '&&colspr' || archive_high || '&&colspr' || total_gb
FROM vcompresstype
ORDER BY total_gb DESC;

spool off

spool opdb__dblinks__&v_tag

WITH vdbl AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id,
       owner,
       count(1) count
FROM   cdb_db_links
WHERE  owner NOT IN
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
GROUP BY '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       con_id, owner)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || count
FROM vdbl;

spool off

spool opdb__dbparameters__&v_tag

WITH vparam AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                   AS pkey,
       inst_id,
       con_id,
       REPLACE(name, ',', '/')                         name,
       REPLACE(SUBSTR(value, 1, 60), ',', '/')         value,
       REPLACE(SUBSTR(default_value, 1, 30), ',', '/') default_value,
       isdefault
FROM   gv$parameter
ORDER  BY 2,3 )
SELECT pkey || '&&colspr' || inst_id || '&&colspr' || con_id || '&&colspr' || name || '&&colspr' || value || '&&colspr' || default_value || '&&colspr' || isdefault
FROM vparam;

spool off

spool opdb__dbfeatures__&v_tag

WITH vdbf AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                                 AS pkey,
       con_id,
       REPLACE(name, ',', '/')                       name,
       currently_used,
       detected_usages,
       total_samples,
       TO_CHAR(first_usage_date, 'MM/DD/YY HH24:MI') first_usage,
       TO_CHAR(last_usage_date, 'MM/DD/YY HH24:MI')  last_usage,
       aux_count
FROM   cdb_feature_usage_statistics
ORDER  BY name)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || name || '&&colspr' || currently_used || '&&colspr' || detected_usages || '&&colspr' ||
       total_samples || '&&colspr' || first_usage || '&&colspr' || last_usage || '&&colspr' || aux_count
FROM vdbf;

spool off

spool opdb__dbhwmarkstatistics__&v_tag

WITH vhwmst AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       description,
       highwater,
       last_value
FROM   dba_high_water_mark_statistics
ORDER  BY description)
SELECT pkey || '&&colspr' || description || '&&colspr' || highwater || '&&colspr' || last_value
FROM vhwmst;

spool off

spool opdb__cpucoresusage__&v_tag

WITH vcpursc AS (
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
ORDER  BY timestamp)
SELECT pkey || '&&colspr' || dt || '&&colspr' || cpu_count || '&&colspr' || cpu_core_count || '&&colspr' || cpu_socket_count
FROM vcpursc;

spool off

spool opdb__dbobjects__&v_tag

WITH vdbobj AS (
        SELECT '&&v_host'
               || '_'
               || '&&v_dbname'
               || '_'
               || '&&v_hora' AS pkey,
               con_id,
               owner,
               object_type,
               editionable,
               COUNT(1)              count,
               GROUPING(con_id)      in_con_id,
               GROUPING(owner)       in_owner,
               GROUPING(object_type) in_OBJECT_TYPE,
               GROUPING(editionable) in_EDITIONABLE
        FROM   cdb_objects
        WHERE  owner NOT IN
                            (
                            SELECT name
                            FROM   SYSTEM.logstdby$skip_support
                            WHERE  action=0)
        GROUP  BY grouping sets ( ( con_id, object_type ), (
                                  con_id, owner, editionable,
                                             object_type ) ))
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || object_type || '&&colspr' || editionable || '&&colspr' ||
       count || '&&colspr' || in_con_id || '&&colspr' || in_owner || '&&colspr' || in_object_type || '&&colspr' || in_editionable
FROM vdbobj;

spool off

spool opdb__sourcecode__&v_tag

WITH vsrc AS (
SELECT pkey,
       con_id,
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
               con_id,
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
        FROM   cdb_source
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
                  con_id,
                  owner,
                  name,
                  TYPE)
GROUP  BY pkey,
          con_id,
          owner,
          TYPE)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || type || '&&colspr' || sum_nr_lines || '&&colspr' || qt_objs || '&&colspr' ||
       sum_nr_lines_w_utl || '&&colspr' || sum_nr_lines_w_dbms || '&&colspr' || count_exec_im || '&&colspr' || count_dbms_sql || '&&colspr' || sum_nr_lines_w_dbms_utl || '&&colspr' || sum_count_total
FROM vsrc;

spool off

spool opdb__indexestypes__&v_tag

WITH vidxtype AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id,
       owner,
       index_type,
       COUNT(1) as cnt
FROM   cdb_indexes
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
          con_id,
          owner,
          index_type)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || index_type || '&&colspr' || cnt
FROM vidxtype;

spool off

spool opdb__datatypes__&v_tag

WITH vdtype AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id,
       owner,
       data_type,
       COUNT(1) as cnt
FROM   cdb_tab_columns
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
          con_id,
          owner,
          data_type)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || data_type || '&&colspr' || cnt
FROM vdtype;

spool off

spool opdb__tablesnopk__&v_tag

WITH vnopk AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'              AS pkey,
       con_id,
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
FROM   (SELECT a.con_id,
               a.owner,
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
        FROM   cdb_tables a
               left outer join cdb_constraints b
                            ON a.con_id = b.con_id
                               AND a.owner = b.owner
                               AND a.table_name = b.table_name)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          con_id,
          owner)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || pk || '&&colspr' || uk || '&&colspr' || ck || '&&colspr' ||
       ri || '&&colspr' || vwck || '&&colspr' || vwro || '&&colspr' || hashexpr || '&&colspr' || suplog || '&&colspr' || num_tables || '&&colspr' || total_cons
FROM vnopk;

spool off

spool opdb__awrhistsysmetrichist__&v_tag

WITH vsysmetric AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                            AS pkey,
       hsm.dbid,
       hsm.instance_number,
       TO_CHAR(hsm.begin_time, 'hh24')          hour,
       hsm.metric_name,
       hsm.metric_unit,
       ROUND(AVG(hsm.value))                           avg_value,
       ROUND(STATS_MODE(hsm.value))                    mode_value,
       ROUND(MEDIAN(hsm.value))                        median_value,
       ROUND(MIN(hsm.value))                           min_value,
       ROUND(MAX(hsm.value))                           max_value,
       ROUND(SUM(hsm.value))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY hsm.value DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY hsm.value DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY hsm.value DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY hsm.value DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY hsm.value DESC)) AS "PERC100"
FROM   dba_hist_sysmetric_history hsm
       inner join dba_hist_snapshot dhsnap
               ON hsm.snap_id = dhsnap.snap_id
                  AND hsm.instance_number = dhsnap.instance_number
                  AND hsm.dbid = dhsnap.dbid
WHERE  hsm.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND hsm.dbid = '&&v_dbid'
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
          TO_CHAR(hsm.begin_time, 'hh24'))
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || metric_name || '&&colspr' ||
       metric_unit || '&&colspr' || avg_value || '&&colspr' || mode_value || '&&colspr' || median_value || '&&colspr' || min_value || '&&colspr' || max_value || '&&colspr' ||
	   sum_value || '&&colspr' || PERC50 || '&&colspr' || PERC75 || '&&colspr' || PERC90 || '&&colspr' || PERC95 || '&&colspr' || PERC100
FROM vsysmetric;

spool off

spool opdb__awrhistsysmetricsumm__&v_tag

WITH vsysmetricsumm AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                            AS pkey,
       hsm.dbid,
       hsm.instance_number,
       TO_CHAR(hsm.begin_time, 'hh24')          hour,
       hsm.metric_name,
       hsm.metric_unit,
       hsm.AVERAGE                           avg_value,
       null                                  mode_value,
       null                                  median_value,
       MINVAL                                min_value,
       MAXVAL                                max_value,
       null                                  sum_value,
       null                                  "PERC50",
       null                                  "PERC75",
       null                                  "PERC90",
       hsm.AVERAGE+(2*hsm.STANDARD_DEVIATION) "PERC95",
       MAXVAL                                 "PERC100"
FROM   DBA_HIST_SYSMETRIC_SUMMARY hsm
       inner join dba_hist_snapshot dhsnap
               ON hsm.snap_id = dhsnap.snap_id
                  AND hsm.instance_number = dhsnap.instance_number
                  AND hsm.dbid = dhsnap.dbid
WHERE  hsm.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND hsm.dbid = '&&v_dbid'),
vsysmetricsummperhour as (
    SELECT pkey,
       hsm.dbid,
       hsm.instance_number,
       hour,
       hsm.metric_name,
       hsm.metric_unit,
       ROUND(AVG(hsm.PERC95))                           avg_value,
       ROUND(STATS_MODE(hsm.PERC95))                    mode_value,
       ROUND(MEDIAN(hsm.PERC95))                        median_value,
       ROUND(MIN(hsm.PERC95))                           min_value,
       ROUND(MAX(hsm.PERC95))                           max_value,
       ROUND(SUM(hsm.PERC95))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY hsm.PERC95 DESC)) AS "PERC100"
    FROM vsysmetricsumm hsm
    GROUP  BY pkey,
            hsm.dbid,
            hsm.instance_number,
            hour,
            hsm.metric_name,
            hsm.metric_unit--, dhsnap.STARTUP_TIME
)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || metric_name || '&&colspr' ||
       metric_unit || '&&colspr' || avg_value || '&&colspr' || mode_value || '&&colspr' || median_value || '&&colspr' || min_value || '&&colspr' || max_value || '&&colspr' ||
	   sum_value || '&&colspr' || PERC50 || '&&colspr' || PERC75 || '&&colspr' || PERC90 || '&&colspr' || PERC95 || '&&colspr' || PERC100
FROM vsysmetricsummperhour;

spool off

spool opdb__awrhistosstat__&v_tag

WITH v_osstat_all
     AS (SELECT os.dbid,
                     os.instance_number,
                     TO_CHAR(os.begin_interval_time, 'hh24') hh24,
                     os.stat_name,
                     os.value cumulative_value,
                     os.delta_value,
                     ( TO_NUMBER(CAST(os.end_interval_time AS DATE) - CAST(os.begin_interval_time AS DATE)) * 60 * 60 * 24 )
                        snap_total_secs,
                     PERCENTILE_CONT(0.5)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC50",
                     PERCENTILE_CONT(0.25)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC75",
                     PERCENTILE_CONT(0.1)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC90",
                     PERCENTILE_CONT(0.05)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC95",
                     PERCENTILE_CONT(0)
                       within GROUP (ORDER BY os.delta_value DESC) over (
                         PARTITION BY os.dbid, os.instance_number,
                       TO_CHAR(os.begin_interval_time, 'hh24'), os.stat_name) AS
                     "PERC100"
              FROM (SELECT snap.begin_interval_time, snap.end_interval_time, s.*,
                    NVL(DECODE(GREATEST(value, NVL(LAG(value)
                    OVER (
                    PARTITION BY s.dbid, s.instance_number, s.stat_name
                    ORDER BY s.snap_id), 0)), value, value - LAG(value)
                       OVER (
                       PARTITION BY s.dbid, s.instance_number, s.stat_name
                       ORDER BY s.snap_id),
                    0), 0) AS delta_value
                    FROM dba_hist_osstat s
                         inner join dba_hist_snapshot snap
                         ON s.snap_id = snap.snap_id
                         AND s.instance_number = snap.instance_number
                         AND s.dbid = snap.dbid
                    WHERE s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
                    AND s.dbid = '&&v_dbid') os ) ,
vossummary AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'        AS pkey,
       dbid,
       instance_number,
       hh24,
       stat_name,
       ROUND(SUM(snap_total_secs))       hh24_total_secs,
       ROUND(AVG(cumulative_value))      cumulative_value,
       ROUND(AVG(delta_value))           avg_value,
       ROUND(STATS_MODE(delta_value))    mode_value,
       ROUND(MEDIAN(delta_value))        median_value,
       ROUND(AVG(perc50))                PERC50,
       ROUND(AVG(perc75))                PERC75,
       ROUND(AVG(perc90))                PERC90,
       ROUND(AVG(perc95))                PERC95,
       ROUND(AVG(perc100))               PERC100,
       ROUND(MIN(delta_value))           min_value,
       ROUND(MAX(delta_value))           max_value,
       ROUND(SUM(delta_value))           sum_value,
       COUNT(1)             count
FROM   v_osstat_all
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          dbid,
          instance_number,
          hh24,
          stat_name)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hh24 || '&&colspr' || stat_name || '&&colspr' || hh24_total_secs || '&&colspr' ||
       cumulative_value || '&&colspr' || avg_value || '&&colspr' || mode_value || '&&colspr' || median_value || '&&colspr' || PERC50 || '&&colspr' || PERC75 || '&&colspr' || PERC90 || '&&colspr' || PERC95 || '&&colspr' || PERC100 || '&&colspr' ||
	     min_value || '&&colspr' || max_value || '&&colspr' || sum_value || '&&colspr' || count
FROM vossummary;

spool off

spool opdb__awrhistcmdtypes__&v_tag

WITH vcmdtype AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
	   a.con_id,
       TO_CHAR(c.begin_interval_time, 'hh24') hh24,
       b.command_type,
       COUNT(1)                               cnt,
       ROUND(AVG(buffer_gets_delta))                 AVG_BUFFER_GETS,
       ROUND(AVG(elapsed_time_delta))                AVG_ELASPED_TIME,
       ROUND(AVG(rows_processed_delta))              AVG_ROWS_PROCESSED,
       ROUND(AVG(executions_delta))                  AVG_EXECUTIONS,
       ROUND(AVG(cpu_time_delta))                    AVG_CPU_TIME,
       ROUND(AVG(iowait_delta))                      AVG_IOWAIT,
       ROUND(AVG(clwait_delta))                      AVG_CLWAIT,
       ROUND(AVG(apwait_delta))                      AVG_APWAIT,
       ROUND(AVG(ccwait_delta))                      AVG_CCWAIT,
       ROUND(AVG(plsexec_time_delta))                AVG_PLSEXEC_TIME
FROM   dba_hist_sqlstat a
       inner join dba_hist_sqltext b
               ON ( a.con_id = b.con_id
                    AND a.sql_id = b.sql_id
                    AND a.dbid = b.dbid)
       inner join dba_hist_snapshot c
               ON ( a.snap_id = c.snap_id
               AND a.dbid = c.dbid
               AND a.instance_number = c.instance_number)
WHERE  a.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND a.dbid = '&&v_dbid'
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
		  a.con_id,
          TO_CHAR(c.begin_interval_time, 'hh24'),
          b.command_type)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || hh24 || '&&colspr' || command_type || '&&colspr' || cnt || '&&colspr' || avg_buffer_gets || '&&colspr' || avg_elasped_time || '&&colspr' ||
       avg_rows_processed || '&&colspr' || avg_executions || '&&colspr' || avg_cpu_time || '&&colspr' || avg_iowait || '&&colspr' || avg_clwait || '&&colspr' ||
	   avg_apwait || '&&colspr' || avg_ccwait || '&&colspr' || avg_plsexec_time
FROM vcmdtype;

spool off

spool opdb__dbahistsystimemodel__&v_tag

WITH vtimemodel AS (
SELECT
      '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey,
      dbid,
      instance_number,
      hour,
      stat_name,
       COUNT(1)                             cnt,
       ROUND(AVG(value))                           avg_value,
       ROUND(STATS_MODE(value))                    mode_value,
       ROUND(MEDIAN(value))                        median_value,
       ROUND(MIN(value))                           min_value,
       ROUND(MAX(value))                           max_value,
       ROUND(SUM(value))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY value DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY value DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY value DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY value DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY value DESC)) AS "PERC100"
FROM (
SELECT
       s.snap_id,
       s.dbid,
       s.instance_number,
       s.begin_interval_time,
       to_char(s.begin_interval_time,'hh24') hour,
       g.stat_name,
       NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                        over (
                                          PARTITION BY s.dbid, s.instance_number, g.stat_name
                                          ORDER BY s.snap_id), 0)), value, value - LAG(value)
                                                                                     over (
                                                                                       PARTITION BY s.dbid, s.instance_number, g.stat_name
                                                                                       ORDER BY s.snap_id),
                                                                    0), 0) AS value
FROM   dba_hist_snapshot s,
       dba_hist_sys_time_model g
WHERE  s.snap_id = g.snap_id
       AND s.instance_number = g.instance_number
       AND s.dbid = g.dbid
       AND s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
       AND s.dbid = '&&v_dbid'
)
GROUP BY
      '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora',
      dbid,
      instance_number,
      hour,
      stat_name)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || stat_name || '&&colspr' || cnt || '&&colspr' ||
       avg_value || '&&colspr' || mode_value || '&&colspr' || median_value || '&&colspr' || min_value || '&&colspr' || max_value || '&&colspr' ||
	   sum_value || '&&colspr' || perc50 || '&&colspr' || perc75 || '&&colspr' || perc90 || '&&colspr' || perc95 || '&&colspr' || perc100
FROM vtimemodel;

spool off

spool opdb__dbahistsysstat__&v_tag

WITH vsysstat AS (
SELECT
       '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora' as pkey,
       dbid,
       instance_number,
       hour,
       stat_name,
       COUNT(1)                             cnt,
       ROUND(AVG(value))                           avg_value,
       ROUND(STATS_MODE(value))                    mode_value,
       ROUND(MEDIAN(value))                        median_value,
       ROUND(MIN(value))                           min_value,
       ROUND(MAX(value))                           max_value,
       ROUND(SUM(value))                           sum_value,
       ROUND(PERCENTILE_CONT(0.5)
         within GROUP (ORDER BY value DESC)) AS "PERC50",
       ROUND(PERCENTILE_CONT(0.25)
         within GROUP (ORDER BY value DESC)) AS "PERC75",
       ROUND(PERCENTILE_CONT(0.10)
         within GROUP (ORDER BY value DESC)) AS "PERC90",
       ROUND(PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY value DESC)) AS "PERC95",
       ROUND(PERCENTILE_CONT(0)
         within GROUP (ORDER BY value DESC)) AS "PERC100"
FROM (
SELECT
       s.snap_id,
       s.dbid,
       s.instance_number,
       s.begin_interval_time,
       to_char(s.begin_interval_time,'hh24') hour,
       g.stat_name,
       NVL(DECODE(GREATEST(value, NVL(LAG(value)
                                        over (
                                          PARTITION BY s.dbid, s.instance_number, g.stat_name
                                          ORDER BY s.snap_id), 0)), value, value - LAG(value)
                                                                                     over (
                                                                                       PARTITION BY s.dbid, s.instance_number, g.stat_name
                                                                                       ORDER BY s.snap_id),
                                                                    0), 0) AS VALUE
FROM   dba_hist_snapshot s,
       dba_hist_sysstat g
WHERE  s.snap_id = g.snap_id
       AND s.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
       AND s.dbid = '&&v_dbid'
       AND s.instance_number = g.instance_number
       AND s.dbid = g.dbid
       AND (LOWER(stat_name) LIKE '%db%time%'
       or LOWER(stat_name) LIKE '%redo%time%'
       or LOWER(stat_name) LIKE '%parse%time%'
       or LOWER(stat_name) LIKE 'phy%'
       or LOWER(stat_name) LIKE '%cpu%'
      -- or LOWER(stat_name) LIKE '%hcc%'
       or LOWER(stat_name) LIKE 'cell%phy%'
       or LOWER(stat_name) LIKE 'cell%smart%'
       or LOWER(stat_name) LIKE 'cell%mem%'
       or LOWER(stat_name) LIKE 'cell%flash%'
       or LOWER(stat_name) LIKE '%db%block%'
       or LOWER(stat_name) LIKE '%execute%'
      -- or LOWER(stat_name) LIKE '%lob%'
       or LOWER(stat_name) LIKE 'user%')
)
GROUP BY
          '&&v_host' || '_' || '&&v_dbname' || '_' || '&&v_hora',
          dbid,
          instance_number,
          hour,
          stat_name)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || stat_name || '&&colspr' || cnt || '&&colspr' ||
       avg_value || '&&colspr' || mode_value || '&&colspr' || median_value || '&&colspr' || min_value || '&&colspr' || max_value || '&&colspr' ||
	   sum_value || '&&colspr' || perc50 || '&&colspr' || perc75 || '&&colspr' || perc90 || '&&colspr' || perc95 || '&&colspr' || perc100
FROM vsysstat;

spool off

spool opdb__usrsegatt__&v_tag

WITH vuseg AS (
 SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                          AS pkey,
        con_id,
        owner,
        segment_name,
        segment_type,
        tablespace_name
 FROM cdb_segments
 WHERE tablespace_name IN ('SYSAUX', 'SYSTEM')
 AND owner NOT IN
 (SELECT name
  FROM system.logstdby$skip_support
  WHERE action=0))
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || segment_name || '&&colspr' || segment_type || '&&colspr' || tablespace_name
FROM vuseg;

spool off

spool opdb__sourceconn__&v_tag

WITH vsrcconn AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       has.dbid,
       has.instance_number,
       TO_CHAR(dhsnap.begin_interval_time, 'hh24') hour,
       has.program,
       has.module,
       has.machine,
       scmd.command_name,
       count(1) cnt
FROM DBA_HIST_ACTIVE_SESS_HISTORY has
     INNER JOIN DBA_HIST_SNAPSHOT dhsnap
     ON has.snap_id = dhsnap.snap_id
     AND has.instance_number = dhsnap.instance_number
     AND has.dbid = dhsnap.dbid
        INNER JOIN V$SQLCOMMAND scmd
        ON has.sql_opcode = scmd.COMMAND_TYPE
WHERE  has.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND has.dbid = '&&v_dbid'
AND has.session_type = 'FOREGROUND'
group by '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       TO_CHAR(dhsnap.begin_interval_time, 'hh24'),
       has.dbid,
       has.instance_number,
       has.program,
       has.module,
       has.machine,
       scmd.command_name)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || program || '&&colspr' ||
       module || '&&colspr' || machine || '&&colspr' || command_name || '&&colspr' || cnt
FROM vsrcconn
order by hour;

spool off

spool opdb__exttab__&v_tag

WITH vexttab AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id, owner, table_name, type_owner, type_name, default_directory_owner, default_directory_name
FROM CDB_EXTERNAL_TABLES)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || owner || '&&colspr' || table_name || '&&colspr' || type_owner || '&&colspr' || type_name || '&&colspr' ||
       default_directory_owner || '&&colspr' || default_directory_name
FROM vexttab;

spool off

spool opdb__iofunction__&v_tag

WITH vrawiof AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       snap.begin_interval_time, snap.end_interval_time,
       TO_CHAR(snap.begin_interval_time, 'hh24') hour,
       iof.snap_id, iof.dbid, iof.instance_number, iof.function_id, iof.function_name,
       NVL(DECODE(GREATEST(iof.small_read_megabytes, NVL(LAG(iof.small_read_megabytes)
                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_read_megabytes, iof.small_read_megabytes - LAG(iof.small_read_megabytes)
                                                                       OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_read_mb_delta_value,
       NVL(DECODE(GREATEST(iof.small_write_megabytes, NVL(LAG(iof.small_write_megabytes)
                                                          OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_write_megabytes, iof.small_write_megabytes - LAG(iof.small_write_megabytes)
                                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_write_mb_delta_value,
       NVL(DECODE(GREATEST(iof.small_read_reqs, NVL(LAG(iof.small_read_reqs)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_read_reqs, iof.small_read_reqs - LAG(iof.small_read_reqs)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_read_rq_delta_value,
       NVL(DECODE(GREATEST(iof.small_write_reqs, NVL(LAG(iof.small_write_reqs)
                                                     OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.small_write_reqs, iof.small_write_reqs - LAG(iof.small_write_reqs)
                                                               OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS sm_write_rq_delta_value,
       NVL(DECODE(GREATEST(iof.large_read_megabytes, NVL(LAG(iof.large_read_megabytes)
                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_read_megabytes, iof.large_read_megabytes - LAG(iof.large_read_megabytes)
                                                                       OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_read_mb_delta_value,
       NVL(DECODE(GREATEST(iof.large_write_megabytes, NVL(LAG(iof.large_write_megabytes)
                                                          OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_write_megabytes, iof.large_write_megabytes - LAG(iof.large_write_megabytes)
                                                                         OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_write_mb_delta_value,
       NVL(DECODE(GREATEST(iof.large_read_reqs, NVL(LAG(iof.large_read_reqs)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_read_reqs, iof.large_read_reqs - LAG(iof.large_read_reqs)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_read_rq_delta_value,
       NVL(DECODE(GREATEST(iof.large_write_reqs, NVL(LAG(iof.large_write_reqs)
                                                     OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.large_write_reqs, iof.large_write_reqs - LAG(iof.large_write_reqs)
                                                               OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS lg_write_rq_delta_value,
       NVL(DECODE(GREATEST(iof.number_of_waits, NVL(LAG(iof.number_of_waits)
                                                    OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.number_of_waits, iof.number_of_waits - LAG(iof.number_of_waits)
                                                             OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS no_iowait_delta_value,
       NVL(DECODE(GREATEST(iof.wait_time, NVL(LAG(iof.wait_time)
                                              OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id), 0)),
                  iof.wait_time, iof.wait_time - LAG(iof.wait_time)
                                                 OVER (PARTITION BY iof.dbid, iof.instance_number, iof.function_name ORDER BY iof.snap_id),0), 0) AS tot_watime_delta_value
FROM DBA_HIST_IOSTAT_FUNCTION iof
INNER JOIN DBA_HIST_SNAPSHOT snap
ON iof.snap_id = snap.snap_id
AND iof.instance_number = snap.instance_number
AND iof.dbid = snap.dbid
WHERE snap.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND snap.dbid = '&&v_dbid'),
vperciof AS (
SELECT pkey,
       dbid,
       instance_number,
       hour,
       function_name,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_read_mb_delta_value DESC) AS sm_read_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_write_mb_delta_value DESC) AS sm_write_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_read_rq_delta_value DESC) AS sm_read_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY sm_write_rq_delta_value DESC) AS sm_write_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_read_mb_delta_value DESC) AS lg_read_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_write_mb_delta_value DESC) AS lg_write_mb_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_read_rq_delta_value DESC) AS lg_read_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY lg_write_rq_delta_value DESC) AS lg_write_rq_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY no_iowait_delta_value DESC) AS no_iowait_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY tot_watime_delta_value DESC) AS tot_watime_delta_value_P95
FROM vrawiof
GROUP BY pkey,
         dbid,
         instance_number,
         hour,
         function_name),
viof AS(
SELECT pkey,
       dbid,
       instance_number,
       hour,
       function_name,
       ROUND(sm_read_mb_delta_value_P95) sm_read_mb_delta_value_P95,
       ROUND(sm_write_mb_delta_value_P95) sm_write_mb_delta_value_P95,
       ROUND(sm_read_rq_delta_value_P95) sm_read_rq_delta_value_P95,
       ROUND(sm_write_rq_delta_value_P95) sm_write_rq_delta_value_P95,
       ROUND(lg_read_mb_delta_value_P95) lg_read_mb_delta_value_P95,
       ROUND(lg_write_mb_delta_value_P95) lg_write_mb_delta_value_P95,
       ROUND(lg_read_rq_delta_value_P95) lg_read_rq_delta_value_P95,
       ROUND(lg_write_rq_delta_value_P95) lg_write_rq_delta_value_P95,
       ROUND(no_iowait_delta_value_P95) no_iowait_delta_value_P95,
       ROUND(tot_watime_delta_value_P95) tot_watime_delta_value_P95,
       ROUND(sm_read_mb_delta_value_P95 + lg_read_mb_delta_value_P95) total_reads_mb_P95,
       ROUND(sm_read_rq_delta_value_P95 + lg_read_rq_delta_value_P95) total_reads_req_P95,
       ROUND(sm_write_mb_delta_value_P95 + lg_write_mb_delta_value_P95) total_writes_mb_P95,
       ROUND(sm_write_rq_delta_value_P95 + lg_write_rq_delta_value_P95) total_write_req_P95
FROM vperciof)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || function_name || '&&colspr' ||
       sm_read_mb_delta_value_P95 || '&&colspr' ||
       sm_write_mb_delta_value_P95 || '&&colspr' ||
       sm_read_rq_delta_value_P95 || '&&colspr' ||
       sm_write_rq_delta_value_P95 || '&&colspr' ||
       lg_read_mb_delta_value_P95 || '&&colspr' ||
       lg_write_mb_delta_value_P95 || '&&colspr' ||
       lg_read_rq_delta_value_P95 || '&&colspr' ||
       lg_write_rq_delta_value_P95 || '&&colspr' ||
       no_iowait_delta_value_P95 || '&&colspr' ||
       tot_watime_delta_value_P95 || '&&colspr' ||
       total_reads_mb_P95 || '&&colspr' ||
       total_reads_req_P95 || '&&colspr' ||
       total_writes_mb_P95 || '&&colspr' ||
       total_write_req_P95
FROM viof;

spool off

spool opdb__ioevents__&v_tag

WITH vrawev AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora'                            AS pkey,
       sev.dbid,
       sev.instance_number,
       dhsnap.begin_interval_time,
       to_char(dhsnap.begin_interval_time,'hh24') hour,
       sev.wait_class,
       sev.event_name,
       sev.total_waits,
       NVL(DECODE(GREATEST(sev.total_waits, NVL(LAG(sev.total_waits)
                                                         OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id), 0)),
                  sev.total_waits, sev.total_waits - LAG(sev.total_waits)
                                                                       OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id),0), 0) AS tot_waits_delta_value,
       sev.total_timeouts,
       NVL(DECODE(GREATEST(sev.total_timeouts, NVL(LAG(sev.total_timeouts)
                                                        OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id), 0)),
                  sev.total_timeouts, sev.total_timeouts - LAG(sev.total_timeouts)
                                                                      OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id),0), 0) AS tot_tout_delta_value,
       sev.time_waited_micro,
       NVL(DECODE(GREATEST(sev.time_waited_micro, NVL(LAG(sev.time_waited_micro)
                                                        OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id), 0)),
                  sev.time_waited_micro, sev.time_waited_micro - LAG(sev.time_waited_micro)
                                                                      OVER (PARTITION BY sev.dbid, sev.instance_number, sev.event_name ORDER BY sev.snap_id),0), 0) AS time_wa_us_delta_value
FROM DBA_HIST_SYSTEM_EVENT sev
     INNER JOIN DBA_HIST_SNAPSHOT dhsnap
     ON sev.snap_id = dhsnap.snap_id
     AND sev.instance_number = dhsnap.instance_number
     AND sev.dbid = dhsnap.dbid
WHERE  sev.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND sev.dbid = '&&v_dbid'
AND sev.wait_class IN ('User I/O', 'System I/O', 'Commit')),
vpercev AS(
SELECT pkey,
       dbid,
       instance_number,
       hour,
       wait_class,
       event_name,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY tot_waits_delta_value DESC) AS tot_waits_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY tot_tout_delta_value DESC) AS tot_tout_delta_value_P95,
       PERCENTILE_CONT(0.05)
         within GROUP (ORDER BY time_wa_us_delta_value DESC) AS time_wa_us_delta_value_P95
FROM vrawev
GROUP BY pkey,
         dbid,
         instance_number,
         hour,
         wait_class,
         event_name),
vfev as(
SELECT pkey,
       dbid,
       instance_number,
       hour,
       wait_class,
       event_name,
       ROUND(tot_waits_delta_value_P95) tot_waits_delta_value_P95,
       ROUND(tot_tout_delta_value_P95) tot_tout_delta_value_P95,
       ROUND(time_wa_us_delta_value_P95) time_wa_us_delta_value_P95
FROM vpercev)
SELECT pkey || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || hour || '&&colspr' || wait_class || '&&colspr' || event_name || '&&colspr' ||
       tot_waits_delta_value_P95 || '&&colspr' ||
       tot_tout_delta_value_P95 || '&&colspr' ||
       time_wa_us_delta_value_P95
FROM vfev;

spool off

spool opdb__sqlstats__&v_tag

WITH vsqlstat AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       sqs.con_id,
	     dhsnap.dbid,
       dhsnap.instance_number,
       to_char(force_matching_signature) force_matching_signature,
       min(sql_id) sql_id,
       ROUND(sum(executions_delta)) total_executions,
       ROUND(sum(px_servers_execs_delta)) total_px_servers_execs,
       ROUND(sum(elapsed_time_total)) elapsed_time_total,
       ROUND(sum(disk_reads_delta)) disk_reads_total,
       ROUND(sum(physical_read_bytes_delta)) physical_read_bytes_total,
       ROUND(sum(physical_write_bytes_delta)) physical_write_bytes_total,
       ROUND(sum(io_offload_elig_bytes_delta)) io_offload_elig_bytes_total,
       ROUND(sum(io_interconnect_bytes_delta)) io_interconnect_bytes_total,
       ROUND(sum(optimized_physical_reads_delta)) optimized_physical_reads_total,
       ROUND(sum(cell_uncompressed_bytes_delta)) cell_uncompressed_bytes_total,
       ROUND(sum(io_offload_return_bytes_delta)) io_offload_return_bytes_total,
       ROUND(sum(direct_writes_delta)) direct_writes_total,
       trunc(decode(sum(executions_delta), 0, 0, (sum(end_of_fetch_count_delta)*100)/sum(executions_delta))) perc_exec_finished,
       trunc(decode(sum(executions_delta), 0, 0, sum(rows_processed_delta)/sum(executions_delta))) avg_rows,
       trunc(decode(sum(executions_delta), 0, 0, sum(disk_reads_delta)/sum(executions_delta))) avg_disk_reads,
       trunc(decode(sum(executions_delta), 0, 0, sum(buffer_gets_delta)/sum(executions_delta))) avg_buffer_gets,
       trunc(decode(sum(executions_delta), 0, 0, sum(cpu_time_delta)/sum(executions_delta))) avg_cpu_time_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(elapsed_time_delta)/sum(executions_delta))) avg_elapsed_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(iowait_delta)/sum(executions_delta))) avg_iowait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(clwait_delta)/sum(executions_delta))) avg_clwait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(apwait_delta)/sum(executions_delta))) avg_apwait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(ccwait_delta)/sum(executions_delta))) avg_ccwait_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(plsexec_time_delta)/sum(executions_delta))) avg_plsexec_us,
       trunc(decode(sum(executions_delta), 0, 0, sum(javexec_time_delta)/sum(executions_delta))) avg_javexec_us
FROM dba_hist_sqlstat sqs, dba_hist_snapshot dhsnap
WHERE sqs.snap_id = dhsnap.snap_id
AND sqs.instance_number = dhsnap.instance_number
AND sqs.dbid = dhsnap.dbid
AND dhsnap.snap_id BETWEEN '&&v_min_snapid' AND '&&v_max_snapid'
AND dhsnap.dbid = '&&v_dbid'
--and t.command_type <> 47
-- and s.executions_total > 100
GROUP BY '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       sqs.con_id, dhsnap.dbid, dhsnap.instance_number, force_matching_signature
ORDER BY elapsed_time_total DESC)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || dbid || '&&colspr' || instance_number || '&&colspr' || force_matching_signature || '&&colspr' || sql_id || '&&colspr' ||
       total_executions || '&&colspr' || total_px_servers_execs || '&&colspr' || elapsed_time_total || '&&colspr' || disk_reads_total || '&&colspr' ||
       physical_read_bytes_total || '&&colspr' || physical_write_bytes_total || '&&colspr' || io_offload_elig_bytes_total || '&&colspr' || io_interconnect_bytes_total || '&&colspr' ||
       optimized_physical_reads_total || '&&colspr' || cell_uncompressed_bytes_total || '&&colspr' || io_offload_return_bytes_total || '&&colspr' || direct_writes_total || '&&colspr' ||
       perc_exec_finished || '&&colspr' || avg_rows || '&&colspr' || avg_disk_reads || '&&colspr' || avg_buffer_gets || '&&colspr' || avg_cpu_time_us || '&&colspr' || avg_elapsed_us || '&&colspr' || avg_iowait_us || '&&colspr' ||
       avg_clwait_us || '&&colspr' || avg_apwait_us || '&&colspr' || avg_ccwait_us || '&&colspr' || avg_plsexec_us || '&&colspr' || avg_javexec_us
FROM vsqlstat
WHERE rownum < 300;

spool off

spool opdb__idxpertable__&v_tag

WITH vrawidx AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id, table_owner, table_name, count(1) idx_cnt
FROM cdb_indexes
WHERE  owner NOT IN
                    ( SELECT name
                      FROM   SYSTEM.logstdby$skip_support
                      WHERE  action=0)
group by con_id, table_owner, table_name),
vcidx AS (
SELECT pkey,
       con_id,
       count(table_name) tab_count,
       idx_cnt,
       round(100*ratio_to_report(count(table_name)) over ()) idx_perc
FROM vrawidx
GROUP BY pkey, con_id, idx_cnt)
SELECT pkey || '&&colspr' || con_id || '&&colspr' || tab_count || '&&colspr' || idx_cnt || '&&colspr' || idx_perc
FROM vcidx;

spool off
