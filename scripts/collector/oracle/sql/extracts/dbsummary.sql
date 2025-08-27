--
-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License").
-- you may not use this file except in compliance with the License.
-- You may obtain a copy of the License at
--
--     https://www.apache.org/licenses/LICENSE-2.0
--
-- Unless required by applicable law or agreed to in writing, software
-- distributed under the License is distributed on an "AS IS" BASIS,
-- WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
-- See the License for the specific language governing permissions and
-- limitations under the License.
--
exec dbms_application_info.set_action('dbsummary');

WITH vdbsummary AS (
SELECT :v_pkey AS pkey,
       (SELECT dbid
        FROM   v$database)                                                      AS dbid,
       (SELECT name
        FROM   v$database)                                                      AS db_name,
       (SELECT &s_db_container_col.
        FROM   v$database)                                                      AS cdb,
       (SELECT version
        FROM   v$instance)                                                      AS db_version,
       (SELECT REPLACE( &s_banner_ver_col. , CHR(10), ' ') as banner
        FROM   v$version
        WHERE  ROWNUM < 2)                                                      AS db_fullversion,
       (SELECT log_mode
        FROM   v$database)                                                      AS log_mode,
       (SELECT force_logging
        FROM   v$database)                                                      AS force_logging,
       (SELECT ( ROUND(AVG(conta) * AVG(bytes) / 1024 / 1024 / 1024) )
        FROM   (SELECT TRUNC(first_time) dia,
                       COUNT(*)          conta
                FROM   v$log_history
                WHERE  first_time >= TRUNC(SYSDATE) - :v_statsWindow
                       AND first_time < TRUNC(SYSDATE)
                GROUP  BY TRUNC(first_time)),
               v$log)                                                           AS redo_gb_per_day,
       (SELECT COUNT(1)
        FROM   gv$instance)                                                     AS rac_dbinstances,
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
       (SELECT &s_platform_name. as  platform_name
        FROM   v$database)                                                      AS platform_name,
       (SELECT TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS')
        FROM   v$instance)                                                      AS startup_time,
       (SELECT COUNT(1)
        FROM   &s_tblprefix._users
        WHERE  username NOT IN
@sql/extracts/exclude_schemas.sql
       )
                                                                               AS user_schemas,
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
        FROM   &s_tblprefix._data_files)                                                  db_size_allocated_gb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   &s_tblprefix._segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' ))                                AS db_size_in_use_gb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   &s_tblprefix._segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' )
               AND ( owner, segment_name ) IN (SELECT owner,
                                                      table_name
                                               FROM   &s_tblprefix._tab_columns
                                               WHERE  data_type LIKE '%LONG%')) AS db_long_size_gb,
       (SELECT database_role
        FROM   v$database)                                                      AS dg_database_role,
       (SELECT protection_mode
        FROM   v$database)                                                      AS dg_protection_mode,
       (SELECT protection_level
        FROM   v$database)                                                      AS dg_protection_level,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   &s_tblprefix._temp_files)                                        AS db_size_temp_allocated_gb,
       (SELECT  ( ROUND(SUM(l.bytes) / 1024 / 1024 / 1024 ) )
        FROM v$log l,
             v$logfile f
        WHERE f.group# = l.group#     )                                         AS db_size_redo_allocated_gb,
@sql/extracts/app_schemas_dbsummary.sql 
        , (SELECT &s_db_unique_name. as db_unique_name
           FROM v$database)                                                     AS db_unique_name,
       (SELECT count(distinct destination) FROM gv$archive_dest WHERE status = 'VALID' AND target = 'STANDBY') as dg_standby_count
FROM   dual)
SELECT pkey , dbid , db_name , cdb , db_version , db_fullversion , log_mode , force_logging ,
       redo_gb_per_day , rac_dbinstances , characterset , platform_name , startup_time , user_schemas ,
	   buffer_cache_mb , shared_pool_mb , total_pga_allocated_mb , db_size_allocated_gb , db_size_in_use_gb ,
	   db_long_size_gb , dg_database_role , dg_protection_mode , dg_protection_level,
           db_size_temp_allocated_gb, db_size_redo_allocated_gb,
           CASE WHEN &s_db_container_col. = 'N/A' THEN ebs_owner ELSE NULL END as ebs_owner, 
           CASE WHEN &s_db_container_col. = 'N/A' THEN siebel_owner ELSE NULL END as siebel_owner, 
           CASE WHEN &s_db_container_col. = 'N/A' THEN psft_owner ELSE NULL END as psft_owner, 
           rds_flag, oci_autonomous_flag, dbms_cloud_pkg_installed,
           CASE WHEN &s_db_container_col. = 'N/A' THEN apex_installed ELSE NULL END as apex_installed, 
           CASE WHEN &s_db_container_col. = 'N/A' THEN sap_owner ELSE NULL END as sap_owner, 
           db_unique_name, dg_standby_count,
           :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vdbsummary;

set echo off
set verify off
