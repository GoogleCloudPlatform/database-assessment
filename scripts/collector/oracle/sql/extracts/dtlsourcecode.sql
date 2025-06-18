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
exec dbms_application_info.set_action('dtlsourcecode');


WITH vsrc AS (
SELECT pkey,
       src.con_id,
       src.owner,
       src.name,
       src.type,
       trigger_type,
       triggering_event,
       base_object_type,
       SUM(nr_lines)       sum_nr_lines,
       COUNT(1)            qt_objs,
       SUM(count_utl)      sum_nr_lines_w_utl,
       SUM(count_dbms)     sum_nr_lines_w_dbms,
       SUM(count_exec_im)  count_exec_im,
       SUM(count_dbms_sql) count_dbms_sql,
       SUM(count_dbms_utl) sum_nr_lines_w_dbms_utl,
       SUM(count_total)    sum_count_total
FROM   (SELECT :v_pkey AS pkey,
               &s_a_con_id. AS con_id,
               a.owner,
               a.name,
               a.TYPE,
               MAX(a.line)     NR_LINES,
               COUNT(CASE
                       WHEN LOWER(a.text) LIKE '%utl_%' THEN 1
                     END)    count_utl,
               COUNT(CASE
                       WHEN LOWER(a.text) LIKE '%dbms_%' THEN 1
                     END)    count_dbms,
               COUNT(CASE
                       WHEN LOWER(a.text) LIKE '%dbms_%'
                            AND LOWER(a.text) LIKE '%utl_%' THEN 1
                     END)    count_dbms_utl,
               COUNT(CASE
                       WHEN LOWER(a.text) LIKE '%execute%immediate%' THEN 1
                     END)    count_exec_im,
               COUNT(CASE
                       WHEN LOWER(a.text) LIKE '%dbms_sql%' THEN 1
                     END)    count_dbms_sql,
               COUNT(1)      count_total
        FROM   &s_tblprefix._source a
        GROUP  BY :v_pkey,
                  &s_a_con_id. ,
                  a.owner,
                  a.name,
                  a.type
       ) src
        LEFT JOIN &s_tblprefix._triggers t ON &s_t_con_id. = src.con_id
                                           AND t.owner = src.owner
                                           AND t.trigger_name = src.name
        WHERE  (t.trigger_name IS NULL 
                AND src.owner NOT IN
@sql/extracts/exclude_schemas.sql
)
               OR (
        TRIM(t.base_object_type) IN ( 'DATABASE', 'SCHEMA' )
    AND t.status = 'ENABLED'
    AND ( t.owner, t.trigger_name ) NOT IN ( ( 'SYS', 'XDB_PI_TRIG' ),
                                             ( 'SYS', 'DELETE_ENTRIES' ),
                                             ( 'SYS', 'OJDS$ROLE_TRIGGER$' ),
                                             ( 'SYS', 'DBMS_SET_PDB' ),
                                             ( 'MDSYS', 'SDO_TOPO_DROP_FTBL' ),
                                             ( 'MDSYS', 'SDO_GEOR_BDDL_TRIGGER' ),
                                             ( 'MDSYS', 'SDO_GEOR_ADDL_TRIGGER' ),
                                             ( 'MDSYS', 'SDO_NETWORK_DROP_USER' ),
                                             ( 'MDSYS', 'SDO_ST_SYN_CREATE' ),
                                             ( 'MDSYS', 'SDO_DROP_USER' ),
                                             ( 'GSMADMIN_INTERNAL', 'GSMLOGOFF' ) ,
                                             ( 'SYSMAN', 'MGMT_STARTUP' ),
                                             ( 'SYS', 'AW_TRUNC_TRG' ),
                                             ( 'SYS', 'AW_REN_TRG' ) ,
                                             ( 'SYS', 'AW_DROP_TRG' )
                                           ))
GROUP  BY pkey,
          src.con_id,
          src.owner,
          src.name,
          src.type,
          t.trigger_type,
          t.triggering_event,
          t.base_object_type)
SELECT pkey , con_id , owner, name , type , sum_nr_lines , qt_objs ,
       sum_nr_lines_w_utl , sum_nr_lines_w_dbms , count_exec_im , count_dbms_sql , sum_nr_lines_w_dbms_utl , sum_count_total,
       trigger_type,
       triggering_event,
       base_object_type,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vsrc;

