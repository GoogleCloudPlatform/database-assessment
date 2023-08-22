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
define cdbjoin = "AND 1=1"
column FORCE_LOGGING format A15
spool &outputdir/opdb__dbsummary__&v_tag

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
       (SELECT &v_db_container_col
        FROM   v$database)                                                      AS cdb,
       (SELECT version
        FROM   v$instance)                                                      AS db_version,
       (SELECT banner
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
       (SELECT TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS')
        FROM   v$instance)                                                      AS startup_time,
       (SELECT COUNT(1)
        FROM   &v_tblprefix._users
        WHERE  username NOT IN
@&EXTRACTSDIR/exclude_schemas.sql
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
        FROM   &v_tblprefix._data_files)                                                  db_size_allocated_gb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   &v_tblprefix._segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' ))                                AS db_size_in_use_gb,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   &v_tblprefix._segments
        WHERE  owner NOT IN ( 'SYS', 'SYSTEM' )
               AND ( owner, segment_name ) IN (SELECT owner,
                                                      table_name
                                               FROM   &v_tblprefix._tab_columns
                                               WHERE  data_type LIKE '%LONG%')) AS db_long_size_gb,
       (SELECT database_role
        FROM   v$database)                                                      AS dg_database_role,
       (SELECT protection_mode
        FROM   v$database)                                                      AS dg_protection_mode,
       (SELECT protection_level
        FROM   v$database)                                                      AS dg_protection_level,
       (SELECT ( ROUND(SUM(bytes) / 1024 / 1024 / 1024) )
        FROM   &v_tblprefix._temp_files)                                        AS db_size_temp_allocated_gb,
       (SELECT  ( ROUND(SUM(l.bytes) / 1024 / 1024 / 1024 ) )
        FROM v$log l,
             v$logfile f
        WHERE f.group# = l.group#     )                                         AS db_size_redo_allocated_gb,
@&EXTRACTSDIR/app_schemas.sql
        , (SELECT db_unique_name
           FROM v$database)                                                     AS db_unique_name
FROM   dual)
SELECT pkey , dbid , db_name , cdb , db_version , db_fullversion , log_mode , force_logging ,
       redo_gb_per_day , rac_dbinstaces , characterset , platform_name , startup_time , user_schemas ,
	   buffer_cache_mb , shared_pool_mb , total_pga_allocated_mb , db_size_allocated_gb , db_size_in_use_gb ,
	   db_long_size_gb , dg_database_role , dg_protection_mode , dg_protection_level, 
           db_size_temp_allocated_gb, db_size_redo_allocated_gb,
           ebs_owner, siebel_owner, psft_owner, rds_flag, oci_autonomous_flag, dbms_cloud_pkg_installed,
           apex_installed, sap_owner, db_unique_name, '&v_dma_source_id' AS DMA_SOURCE_ID
FROM vdbsummary;
spool off
