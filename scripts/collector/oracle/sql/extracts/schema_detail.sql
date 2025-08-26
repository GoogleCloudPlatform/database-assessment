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
exec dbms_application_info.set_action('schemadetail');

with vobj as (
        SELECT /* + MATERIALIZE */
               &s_a_con_id. AS con_id,
               owner,
               object_type,
               &s_editionable_col. AS editionable,
               object_name,
               status
        FROM &s_tblprefix._objects a
        WHERE  
(
        (
        NOT ( a.object_type IN ('SYNONYM', 'JAVA CLASS') AND a.owner IN ('PUBLIC', 'SYS') /*  AND a.object_name LIKE '%/%' */  )  
        AND a.object_name NOT LIKE 'BIN$%' )
           AND  (owner NOT IN
@sql/extracts/exclude_schemas.sql
)
or (object_type in ('DB_LINK', 'DATABASE LINK', 'DIRECTORY')))
)
,
tblinfo AS ( SELECT /* + MATERIALIZE */ con_id, owner, table_name, partitioned, iot_type, nested, temporary, secondary, clustered_table, object_table, xml_table FROM ( 
	SELECT 
	    &s_a_con_id. AS con_id,
	    a.owner,
	    a.table_name,
	    a.partitioned,
	    a.iot_type,
	    a.nested,
	    a.temporary,
	    a.secondary,
	    CASE
		WHEN a.cluster_name IS NULL THEN
		    'N'
		ELSE
		    'Y'
	    END      AS clustered_table,
	    'N' AS object_table,
	    'N' AS xml_table
	FROM &s_tblprefix._tables a
	WHERE a.owner NOT IN (
@sql/extracts/exclude_schemas.sql
	       )
	UNION ALL
	SELECT
	    &s_b_con_id. AS con_id,
	    b.owner,
	    b.table_name,
	    'NO' partitioned,
	    NULL iot_type,
	    'NO' nested,
	    'N' temporary,
	    'N' secondary,
	    'N' clustered_table,
	    'N' AS object_table,
	    'Y' AS xml_table
        FROM &s_xml_select_dtl. b
	WHERE b.owner NOT IN (
@sql/extracts/exclude_schemas.sql
	       )
	UNION ALL
	SELECT
	    &s_c_con_id. AS con_id,
	    c.owner,
	    c.table_name,
	    c.partitioned,
	    c.iot_type,
	    c.nested,
	    c.temporary,
	    c.secondary,
	    CASE
		WHEN c.cluster_name IS NULL THEN
		    'N'
		ELSE
		    'Y'
	    END      AS clustered_table,
	    'Y' AS object_table,
	    'N' AS xml_table
	FROM &s_tblprefix._object_tables c
	WHERE c.owner NOT IN (
@sql/extracts/exclude_schemas.sql
	       )
        )
),
subpartinfo AS (
	SELECT /* + MATERIALIZE */
               &s_d_con_id. AS con_id,
	       d.table_owner,
	       d.table_name,
	       count(1) cnt
	FROM &s_tblprefix._tab_subpartitions d
	WHERE d.table_owner NOT IN (
@sql/extracts/exclude_schemas.sql
	       )
	GROUP BY &s_d_con_id. ,
	       d.table_owner,
	       d.table_name
),
mv as (
        SELECT /* + MATERIALIZE */ 
	    &s_a_con_id. AS con_id,
	    a.owner,
	    a.mview_name,
	    a.updatable,
	    a.rewrite_enabled,
	    a.refresh_mode,
	    a.refresh_method,
	    a.fast_refreshable,
	    a.compile_state
	FROM &s_tblprefix._mviews a
	WHERE a.owner NOT IN (
@sql/extracts/exclude_schemas.sql
	       )
)  ,
coltypes AS (
  SELECT /* + MATERIALIZE */
    to_char(con_id) as con_id,
    owner, table_name,
--    sum(col_count) AS col_count,
    SUM(CASE WHEN data_type = 'ANYDATA'                           THEN 1 ELSE 0 END) as "ANYDATA_COL_COUNT"                          ,
    SUM(CASE WHEN data_type = 'BFILE'                             THEN 1 ELSE 0 END) as "BFILE_COL_COUNT"                            ,
    SUM(CASE WHEN data_type = 'BINARY_DOUBLE'                     THEN 1 ELSE 0 END) as "BINARY_DOUBLE_COL_COUNT"                    ,
    SUM(CASE WHEN data_type = 'BINARY_FLOAT'                      THEN 1 ELSE 0 END) as "BINARY_FLOAT_COL_COUNT"                     ,
    SUM(CASE WHEN data_type = 'BLOB'                              THEN 1 ELSE 0 END) as "BLOB_COL_COUNT"                             ,
    SUM(CASE WHEN data_type = 'CFILE'                             THEN 1 ELSE 0 END) as "CFILE_COL_COUNT"                            ,
    SUM(CASE WHEN data_type = 'CHAR'                              THEN 1 ELSE 0 END) as "CHAR_COL_COUNT"                             ,
    SUM(CASE WHEN data_type = 'CLOB'                              THEN 1 ELSE 0 END) as "CLOB_COL_COUNT"                             ,
    SUM(CASE WHEN data_type = 'DATE'                              THEN 1 ELSE 0 END) as "DATE_COL_COUNT"                             ,
    SUM(CASE WHEN data_type = 'FLOAT'                             THEN 1 ELSE 0 END) as "FLOAT_COL_COUNT"                            ,
    SUM(CASE WHEN data_type = 'INTERVAL DAY(x) TO SECOND(x)'      THEN 1 ELSE 0 END) as "INTERVAL_DAY_TO_SECOND_COL_COU"             ,
    SUM(CASE WHEN data_type = 'INTERVAL YEAR(x) TO MONTH'         THEN 1 ELSE 0 END) as "INTERVAL_YEAR_TO_MONTH_COL_COU"             ,
    SUM(CASE WHEN data_type = 'JSON'                              THEN 1 ELSE 0 END) as "JSON_COL_COUNT"                             ,
    SUM(CASE WHEN data_type = 'LONG RAW'                          THEN 1 ELSE 0 END) as "LONG_RAW_COL_COUNT"                         ,
    SUM(CASE WHEN data_type = 'LONG'                              THEN 1 ELSE 0 END) as "LONG_COL_COUNT"                             ,
    SUM(CASE WHEN data_type = 'MLSLABEL'                          THEN 1 ELSE 0 END) as "MLSLABEL_COL_COUNT"                         ,
    SUM(CASE WHEN data_type = 'NCHAR VARYING'                     THEN 1 ELSE 0 END) as "NCHAR_VARYING_COL_COUNT"                    ,
    SUM(CASE WHEN data_type = 'NCHAR'                             THEN 1 ELSE 0 END) as "NCHAR_COL_COUNT"                            ,
    SUM(CASE WHEN data_type = 'NCLOB'                             THEN 1 ELSE 0 END) as "NCLOB_COL_COUNT"                            ,
    SUM(CASE WHEN data_type = 'NUMBER'                            THEN 1 ELSE 0 END) as "NUMBER_COL_COUNT"                           ,
    SUM(CASE WHEN data_type = 'NVARCHAR2'                         THEN 1 ELSE 0 END) as "NVARCHAR2_COL_COUNT"                        ,
    SUM(CASE WHEN data_type = 'RAW'                               THEN 1 ELSE 0 END) as "RAW_COL_COUNT"                              ,
    SUM(CASE WHEN data_type = 'ROWID'                             THEN 1 ELSE 0 END) as "ROWID_COL_COUNT"                            ,
    SUM(
    CASE WHEN DATA_TYPE NOT IN (
        'ANYDATA',
        'BFILE',
        'BINARY_DOUBLE',
        'BINARY_FLOAT',
        'BLOB',
        'CFILE',
        'CHAR',
        'CLOB',
        'DATE',
        'FLOAT',
        'INTERVAL DAY(x) TO SECOND(x)',
        'INTERVAL YEAR(x) TO MONTH',
        'JSON' ,
        'LONG RAW',
        'LONG',
        'MLSLABEL',
        'NCHAR VARYING',
        'NCHAR',
        'NCLOB',
        'NUMBER',
        'NVARCHAR2',
        'RAW',
        'ROWID',
        'TIME(x) WITH TIME ZONE',
        'TIME(x)',
        'TIMESTAMP(x) WITH LOCAL TIME ZONE',
        'TIMESTAMP(x) WITH TIME ZONE',
        'TIMESTAMP(x)',
        'UNDEFINED',
        'UROWID',
        'VARCHAR(x)',
        'VARCHAR2',
        'XMLTYPE'
    )
      AND data_type_owner = 'MDSYS' THEN 1 ELSE 0 END) AS "SPATIAL_COL_COUNT",
    SUM(CASE WHEN data_type = 'TIME(x) WITH TIME ZONE'            THEN 1 ELSE 0 END) as "TIME_WITH_TIME_ZONE_COL_COUNT"           ,
    SUM(CASE WHEN data_type = 'TIME(x)'                           THEN 1 ELSE 0 END) as "TIME_COL_COUNT"                          ,
    SUM(CASE WHEN data_type = 'TIMESTAMP(x) WITH LOCAL TIME ZONE' THEN 1 ELSE 0 END) as "TIMESTAMP_WITH_LOCAL_TIME_Z_CO",
    SUM(CASE WHEN data_type = 'TIMESTAMP(x) WITH TIME ZONE'       THEN 1 ELSE 0 END) as "TIMESTAMP_WITH_TIME_ZONE_COL_C"      ,
    SUM(CASE WHEN data_type = 'TIMESTAMP(x)'                      THEN 1 ELSE 0 END) as "TIMESTAMP_COL_COUNT"                     ,
    SUM(CASE WHEN data_type = 'UROWID'                            THEN 1 ELSE 0 END) as "UROWID_COL_COUNT"                           ,
    SUM(CASE WHEN data_type = 'VARCHAR(x)'                        THEN 1 ELSE 0 END) as "VARCHAR_COL_COUNT"                       ,
    SUM(CASE WHEN data_type = 'VARCHAR2'                          THEN 1 ELSE 0 END) as "VARCHAR2_COL_COUNT"                         ,
    SUM(CASE WHEN data_type = 'XMLTYPE'                           THEN 1 ELSE 0 END) as "XMLTYPE_COL_COUNT"                          ,
    SUM(CASE WHEN data_type = 'UNDEFINED'                         THEN 1 ELSE 0 END) as "UNDEFINED_COL_COUNT"                        ,
    SUM(
    CASE WHEN DATA_TYPE NOT IN (
        'ANYDATA',
        'BFILE',
        'BINARY_DOUBLE',
        'BINARY_FLOAT',
        'BLOB',
        'CFILE',
        'CHAR',
        'CLOB',
        'DATE',
        'FLOAT',
        'INTERVAL DAY(x) TO SECOND(x)',
        'INTERVAL YEAR(x) TO MONTH',
        'JSON' ,
        'LONG RAW',
        'LONG',
        'MLSLABEL',
        'NCHAR VARYING',
        'NCHAR',
        'NCLOB',
        'NUMBER',
        'NVARCHAR2',
        'RAW',
        'ROWID',
        'TIME(x) WITH TIME ZONE',
        'TIME(x)',
        'TIMESTAMP(x) WITH LOCAL TIME ZONE',
        'TIMESTAMP(x) WITH TIME ZONE',
        'TIMESTAMP(x)',
        'UNDEFINED',
        'UROWID',
        'VARCHAR(x)',
        'VARCHAR2',
        'XMLTYPE'
    )
      AND data_type_owner NOT IN ('MDSYS') THEN 1 ELSE 0 END) AS "USER_DEFINED_COL_COUNT"
      FROM (
        SELECT /* + USE_HASH(b a) NOPARALLEL */
            &s_a_con_id. AS con_id,
            a.owner,
            table_name,
@sql/extracts/&s_data_type_exp.
            data_type,
            data_type_owner,
            1                                                 AS col_count
        FROM
            &s_tblprefix._tab_columns a INNER JOIN &s_tblprefix._objects b ON &s_a_con_id. = &s_b_con_id. AND a.owner = b.owner AND a.table_name = b.object_name and b.object_type = 'TABLE'
        WHERE
            a.owner NOT IN
@sql/extracts/exclude_schemas.sql
           )
   GROUP BY
    con_id, owner, table_name
)  , 
vexttab AS (
	SELECT /* + MATERIALIZE */
	       &s_a_con_id. as con_id, 
	       owner, 
	       table_name, 
	       type_owner, 
	       type_name, 
	       default_directory_owner, 
	       default_directory_name
	FROM &s_tblprefix._external_tables a) 
,
vsrc as (
SELECT /* + MATERIALIZE */
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
       SUM(count_dbms_utl) sum_nr_lines_w_dbms_utl
FROM   (SELECT /* + MATERIALIZE */
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
                     END)    count_dbms_sql
        FROM   &s_tblprefix._source a
        GROUP  BY 
                  &s_a_con_id. ,
                  a.owner,
                  a.name,
                  a.type
       ) src
        LEFT JOIN &s_tblprefix._triggers t ON &s_t_con_id. = src.con_id
                                           AND t.owner = src.owner
                                           AND t.trigger_name = src.name
        WHERE  (    t.trigger_name IS NULL 
                AND src.owner NOT IN
@sql/extracts/exclude_schemas.sql
               )
               OR (
                       t.base_object_type IN ( 'DATABASE', 'SCHEMA' )
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
                                                          )
                  )
GROUP BY
          src.con_id,
          src.owner,
          src.name,
          src.type,
          t.trigger_type,
          t.triggering_event,
          t.base_object_type ) , 
vidxtype AS (
	SELECT /* + MATERIALIZE */
	       &s_a_con_id. AS con_id,
	       a.owner,
	       a.index_type,
	       a.uniqueness,
	       a.compression,
	       a.partitioned,
	       a.temporary,
	       a.secondary,
	       &s_index_visibility. AS VISIBILITY,
	       a.join_index,
	       CASE WHEN a.ityp_owner IS NOT NULL THEN 'Y' ELSE 'N' END AS custom_index_type,
	       a.table_name,
	       a.index_name
	FROM   &s_tblprefix._indexes a
	WHERE  owner NOT IN
@sql/extracts/exclude_schemas.sql
	),
vseg AS (
        SELECT /* + MATERIALIZE */
	       &s_a_con_id. AS con_id,
               a.owner,
               a.segment_name,
               round(sum(a.bytes)/1024/1024,3) segment_mb,
               sum(case when tablespace_name = 'SYSTEM' then 1 else 0 end) as segments_in_system_ts
        FROM &s_tblprefix._segments a
        GROUP BY &s_a_con_id. ,a.owner,  a.segment_name
),
vtabcons AS (
SELECT /* + MATERIALIZE */
       con_id,
       owner,
       table_name,
       SUM(pk)                    pk,
       SUM(uk)                    uk,
       SUM(ck)                    ck,
       SUM(ri)                    ri,
       SUM(vwck)                  vwck,
       SUM(vwro)                  vwro,
       SUM(hashexpr)              hashexpr,
       SUM(refcolcons)            refcolcons,
       SUM(suplog)                suplog,
       COUNT(1)                   total_cons
FROM   (SELECT &s_a_con_id. AS con_id,
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
        FROM   &s_tblprefix._tables a
               left outer join &s_tblprefix._constraints b
                            ON &s_a_con_id. = &s_b_con_id.
                               AND a.owner = b.owner
                               AND a.table_name = b.table_name
        WHERE a.owner NOT IN
@sql/extracts/exclude_schemas.sql
        )
        GROUP  BY 
          con_id,
          owner,
          table_name),
nncols as (SELECT &s_a_con_id. AS con_id,
                  owner,
                  table_name, 
                  count(1) AS nn_count
           FROM &s_tblprefix._tab_columns a
           WHERE nullable ='N'
             AND owner NOT in
@sql/extracts/exclude_schemas.sql
           GROUP BY &s_a_con_id ,
                    owner,
                    table_name
)
SELECT :v_pkey AS pkey,
       vobj.con_id,
       vobj.owner,
       vobj.object_name,
       vobj.object_type,
       vobj.status,
       ti.partitioned,
       ti.iot_type,
       ti.nested,
       ti.temporary,
       ti.secondary,
       ti.clustered_table,
       ti.object_table,
       ti.xml_table,
       CASE WHEN ext.table_name IS NOT NULL THEN 'Y' ELSE 'N' END as is_external_table,
       p.partitioning_type,
       p.subpartitioning_type,
       p.partition_count,
       sp.cnt AS subpartition_count,
       -- Mview info
       mv.updatable,
       mv.rewrite_enabled,
       mv.refresh_mode,
       mv.refresh_method,
       mv.fast_refreshable,
       mv.compile_state,
       -- Column types
       ct.ANYDATA_COL_COUNT                          ,
       ct.BFILE_COL_COUNT                            ,
       ct.BINARY_DOUBLE_COL_COUNT                    ,
       ct.BINARY_FLOAT_COL_COUNT                     ,
       ct.BLOB_COL_COUNT                             ,
       ct.CFILE_COL_COUNT                            ,
       ct.CHAR_COL_COUNT                             ,
       ct.CLOB_COL_COUNT                             ,
       ct.DATE_COL_COUNT                             ,
       ct.FLOAT_COL_COUNT                            ,
       ct.INTERVAL_DAY_TO_SECOND_COL_COU             ,
       ct.INTERVAL_YEAR_TO_MONTH_COL_COU             ,
       ct.JSON_COL_COUNT                             ,
       ct.LONG_RAW_COL_COUNT                         ,
       ct.LONG_COL_COUNT                             ,
       ct.MLSLABEL_COL_COUNT                         ,
       ct.NCHAR_VARYING_COL_COUNT                    ,
       ct.NCHAR_COL_COUNT                            ,
       ct.NCLOB_COL_COUNT                            ,
       ct.NUMBER_COL_COUNT                           ,
       ct.NVARCHAR2_COL_COUNT                        ,
       ct.RAW_COL_COUNT                              ,
       ct.ROWID_COL_COUNT                            ,
       ct.SPATIAL_COL_COUNT                          ,
       ct.TIME_WITH_TIME_ZONE_COL_COUNT              ,
       ct.TIME_COL_COUNT                             ,
       ct.TIMESTAMP_WITH_LOCAL_TIME_Z_CO             ,
       ct.TIMESTAMP_WITH_TIME_ZONE_COL_C             ,
       ct.TIMESTAMP_COL_COUNT                        ,
       ct.UROWID_COL_COUNT                           ,
       ct.VARCHAR_COL_COUNT                          ,
       ct.VARCHAR2_COL_COUNT                         ,
       ct.XMLTYPE_COL_COUNT                          ,
       ct.UNDEFINED_COL_COUNT                        ,
       ct.USER_DEFINED_COL_COUNT                     , 
       -- Source code
       -- vsrc.type,
       vsrc.sum_nr_lines,
       vsrc.sum_nr_lines_w_utl , 
       vsrc.sum_nr_lines_w_dbms , 
       vsrc.count_exec_im , 
       vsrc.count_dbms_sql , 
       vsrc.sum_nr_lines_w_dbms_utl , 
       vsrc.trigger_type,
       vsrc.triggering_event,
       vsrc.base_object_type,
       -- Index info
       vi.index_type,
       vi.uniqueness as index_uniqueness,
       vi.compression as index_compression,
       vi.partitioned as index_partitioned,
       vi.temporary as index_temporary,
       vi.secondary as index_secondary,
       vi.VISIBILITY as index_visibility,
       vi.join_index as index_join_index,
       vi.custom_index_type as index_custom_index_type,
       vi.table_name as index_table_name,
       vs.segment_mb,
       vs.segments_in_system_ts,
       -- Constraints
       vtabcons.pk as primary_key_count,
       vtabcons.uk as unique_cons_count,
       /* Attempt to aproximate number of check constraints that are more than just 'NOT NULL' by 
          subtracting the number of non-nullable columns from the number of check constraints.
          Multicolumn primary keys will throw this off, so we use a floor of zero.  */
       GREATEST(vtabcons.ck - (nvl(nncols.nn_count ,0) - nvl(vtabcons.pk,0)),0)  as check_cons_count, 
       vtabcons.ri as foreign_key_cons_count,
       vtabcons.vwck as view_check_cons_count,
       vtabcons.vwro as view_read_only_count,
       vtabcons.hashexpr as hash_expr_count,
       vtabcons.refcolcons,
       vtabcons.suplog as supplemental_logging_count,
       nncols.nn_count as nnull_cons_count,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vobj 
LEFT OUTER JOIN tblinfo ti 
              ON ti.owner = vobj.owner
              AND ti.table_name = vobj.object_name
              AND ti.con_id = vobj.con_id
              AND vobj.object_type = 'TABLE'
LEFT OUTER JOIN &s_tblprefix._part_tables p
              ON ti.owner = p.owner
               AND ti.table_name = p.table_name
               AND ti.con_id = &s_p_con_id.
LEFT OUTER JOIN subpartinfo sp
              ON sp.table_owner = p.owner
               AND sp.table_name = p.table_name
               AND sp.con_id = &s_p_con_id.
LEFT OUTER JOIN mv 
              ON mv.con_id = ti.con_id
               AND mv.owner = ti.owner
               AND mv.mview_name = ti.table_name
LEFT OUTER JOIN coltypes ct
              ON ct.owner = ti.owner
              AND ct.table_name = ti.table_name
              AND ct.con_id = ti.con_id
LEFT OUTER JOIN vexttab ext
              ON ext.con_id = ti.con_id
              AND ext.owner = ti.owner
              AND ext.table_name = ti.table_name
LEFT OUTER JOIN vsrc
              ON vsrc.con_id = vobj.con_id
              AND vsrc.owner = vobj.owner
              AND vsrc.name = vobj.object_name
              AND vsrc.type = vobj.object_type
LEFT OUTER JOIN vidxtype vi
              ON vi.con_id = vobj.con_id
              AND vi.owner = vobj.owner
              AND vi.index_name = vobj.object_name
              AND vobj.object_type like '%INDEX%'
LEFT OUTER JOIN vseg vs
              ON vs.con_id = vobj.con_id
              AND vs.owner = vobj.owner
              AND vs.segment_name = vobj.object_name
LEFT OUTER JOIN vtabcons
              ON vtabcons.con_id = ti.con_id
              AND vtabcons.owner = ti.owner
              AND vtabcons.table_name = ti.table_name
LEFT OUTER JOIN nncols
              ON nncols.con_id = vtabcons.con_id
              AND nncols.owner = vtabcons.owner
              AND nncols.table_name = vtabcons.table_name
;

