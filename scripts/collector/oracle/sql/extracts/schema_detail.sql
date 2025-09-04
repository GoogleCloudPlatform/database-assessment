--
-- Copyright 2024 Google LLC
--
-- Licensed under the Apache License, Version 2.0 (the "License");
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
EXEC dbms_application_info.set_action('schemadetail');

WITH vobj AS (
    SELECT
        &s_a_con_id. AS con_id,
        owner,
        object_type,
        &s_editionable_col. AS editionable,
        object_name,
        status
    FROM &s_tblprefix._objects a
    WHERE (
        (
            NOT (
                a.object_type IN ('SYNONYM', 'JAVA CLASS')
                AND a.owner IN ('PUBLIC', 'SYS')
            )
            AND a.object_name NOT LIKE 'BIN$%'
        )
        AND (
            owner NOT IN
@sql/extracts/exclude_schemas.sql
        )
        OR (object_type IN ('DB_LINK', 'DATABASE LINK', 'DIRECTORY'))
    )
),
tblinfo AS (
    SELECT
        con_id,
        owner,
        table_name,
        partitioned,
        iot_type,
        nested,
        temporary,
        secondary,
        clustered_table,
        object_table,
        xml_table
    FROM (
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
                WHEN a.cluster_name IS NULL
                THEN 'N'
                ELSE 'Y'
            END AS clustered_table,
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
            'NO' AS partitioned,
            NULL AS iot_type,
            'NO' AS nested,
            'N' AS temporary,
            'N' AS secondary,
            'N' AS clustered_table,
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
                WHEN c.cluster_name IS NULL
                THEN 'N'
                ELSE 'Y'
            END AS clustered_table,
            'Y' AS object_table,
            'N' AS xml_table
        FROM &s_tblprefix._object_tables c
        WHERE c.owner NOT IN (
@sql/extracts/exclude_schemas.sql
        )
    )
),
subpartinfo AS (
    SELECT
        &s_d_con_id. AS con_id,
        d.table_owner,
        d.table_name,
        COUNT(1) AS cnt
    FROM &s_tblprefix._tab_subpartitions d
    WHERE d.table_owner NOT IN (
@sql/extracts/exclude_schemas.sql
    )
    GROUP BY
        &s_d_con_id.,
        d.table_owner,
        d.table_name
),
mv AS (
    SELECT
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
),
coltypes AS (
    SELECT
        TO_CHAR(con_id) AS con_id,
        owner,
        table_name,
        SUM(CASE WHEN data_type = 'ANYDATA' THEN 1 ELSE 0 END) AS "ANYDATA_COL_COUNT",
        SUM(CASE WHEN data_type = 'BFILE' THEN 1 ELSE 0 END) AS "BFILE_COL_COUNT",
        SUM(CASE WHEN data_type = 'BINARY_DOUBLE' THEN 1 ELSE 0 END) AS "BINARY_DOUBLE_COL_COUNT",
        SUM(CASE WHEN data_type = 'BINARY_FLOAT' THEN 1 ELSE 0 END) AS "BINARY_FLOAT_COL_COUNT",
        SUM(CASE WHEN data_type = 'BLOB' THEN 1 ELSE 0 END) AS "BLOB_COL_COUNT",
        SUM(CASE WHEN data_type = 'CFILE' THEN 1 ELSE 0 END) AS "CFILE_COL_COUNT",
        SUM(CASE WHEN data_type = 'CHAR' THEN 1 ELSE 0 END) AS "CHAR_COL_COUNT",
        SUM(CASE WHEN data_type = 'CLOB' THEN 1 ELSE 0 END) AS "CLOB_COL_COUNT",
        SUM(CASE WHEN data_type = 'DATE' THEN 1 ELSE 0 END) AS "DATE_COL_COUNT",
        SUM(CASE WHEN data_type = 'FLOAT' THEN 1 ELSE 0 END) AS "FLOAT_COL_COUNT",
        SUM(CASE WHEN data_type = 'INTERVAL DAY(x) TO SECOND(x)' THEN 1 ELSE 0 END) AS "INTERVAL_DAY_TO_SECOND_COL_COU",
        SUM(CASE WHEN data_type = 'INTERVAL YEAR(x) TO MONTH' THEN 1 ELSE 0 END) AS "INTERVAL_YEAR_TO_MONTH_COL_COU",
        SUM(CASE WHEN data_type = 'JSON' THEN 1 ELSE 0 END) AS "JSON_COL_COUNT",
        SUM(CASE WHEN data_type = 'LONG RAW' THEN 1 ELSE 0 END) AS "LONG_RAW_COL_COUNT",
        SUM(CASE WHEN data_type = 'LONG' THEN 1 ELSE 0 END) AS "LONG_COL_COUNT",
        SUM(CASE WHEN data_type = 'MLSLABEL' THEN 1 ELSE 0 END) AS "MLSLABEL_COL_COUNT",
        SUM(CASE WHEN data_type = 'NCHAR VARYING' THEN 1 ELSE 0 END) AS "NCHAR_VARYING_COL_COUNT",
        SUM(CASE WHEN data_type = 'NCHAR' THEN 1 ELSE 0 END) AS "NCHAR_COL_COUNT",
        SUM(CASE WHEN data_type = 'NCLOB' THEN 1 ELSE 0 END) AS "NCLOB_COL_COUNT",
        SUM(CASE WHEN data_type = 'NUMBER' THEN 1 ELSE 0 END) AS "NUMBER_COL_COUNT",
        SUM(CASE WHEN data_type = 'NVARCHAR2' THEN 1 ELSE 0 END) AS "NVARCHAR2_COL_COUNT",
        SUM(CASE WHEN data_type = 'RAW' THEN 1 ELSE 0 END) AS "RAW_COL_COUNT",
        SUM(CASE WHEN data_type = 'ROWID' THEN 1 ELSE 0 END) AS "ROWID_COL_COUNT",
        SUM(
            CASE
                WHEN data_type NOT IN (
                    'ANYDATA', 'BFILE', 'BINARY_DOUBLE', 'BINARY_FLOAT', 'BLOB',
                    'CFILE', 'CHAR', 'CLOB', 'DATE', 'FLOAT',
                    'INTERVAL DAY(x) TO SECOND(x)', 'INTERVAL YEAR(x) TO MONTH',
                    'JSON', 'LONG RAW', 'LONG', 'MLSLABEL', 'NCHAR VARYING',
                    'NCHAR', 'NCLOB', 'NUMBER', 'NVARCHAR2', 'RAW', 'ROWID',
                    'TIME(x) WITH TIME ZONE', 'TIME(x)',
                    'TIMESTAMP(x) WITH LOCAL TIME ZONE',
                    'TIMESTAMP(x) WITH TIME ZONE', 'TIMESTAMP(x)', 'UNDEFINED',
                    'UROWID', 'VARCHAR(x)', 'VARCHAR2', 'XMLTYPE'
                )
                AND data_type_owner = 'MDSYS'
                THEN 1
                ELSE 0
            END
        ) AS "SPATIAL_COL_COUNT",
        SUM(CASE WHEN data_type = 'TIME(x) WITH TIME ZONE' THEN 1 ELSE 0 END) AS "TIME_WITH_TIME_ZONE_COL_COUNT",
        SUM(CASE WHEN data_type = 'TIME(x)' THEN 1 ELSE 0 END) AS "TIME_COL_COUNT",
        SUM(CASE WHEN data_type = 'TIMESTAMP(x) WITH LOCAL TIME ZONE' THEN 1 ELSE 0 END) AS "TIMESTAMP_WITH_LOCAL_TIME_Z_CO",
        SUM(CASE WHEN data_type = 'TIMESTAMP(x) WITH TIME ZONE' THEN 1 ELSE 0 END) AS "TIMESTAMP_WITH_TIME_ZONE_COL_C",
        SUM(CASE WHEN data_type = 'TIMESTAMP(x)' THEN 1 ELSE 0 END) AS "TIMESTAMP_COL_COUNT",
        SUM(CASE WHEN data_type = 'UROWID' THEN 1 ELSE 0 END) AS "UROWID_COL_COUNT",
        SUM(CASE WHEN data_type = 'VARCHAR(x)' THEN 1 ELSE 0 END) AS "VARCHAR_COL_COUNT",
        SUM(CASE WHEN data_type = 'VARCHAR2' THEN 1 ELSE 0 END) AS "VARCHAR2_COL_COUNT",
        SUM(CASE WHEN data_type = 'XMLTYPE' THEN 1 ELSE 0 END) AS "XMLTYPE_COL_COUNT",
        SUM(CASE WHEN data_type = 'UNDEFINED' THEN 1 ELSE 0 END) AS "UNDEFINED_COL_COUNT",
        SUM(
            CASE
                WHEN data_type NOT IN (
                    'ANYDATA', 'BFILE', 'BINARY_DOUBLE', 'BINARY_FLOAT', 'BLOB',
                    'CFILE', 'CHAR', 'CLOB', 'DATE', 'FLOAT',
                    'INTERVAL DAY(x) TO SECOND(x)', 'INTERVAL YEAR(x) TO MONTH',
                    'JSON', 'LONG RAW', 'LONG', 'MLSLABEL', 'NCHAR VARYING',
                    'NCHAR', 'NCLOB', 'NUMBER', 'NVARCHAR2', 'RAW', 'ROWID',
                    'TIME(x) WITH TIME ZONE', 'TIME(x)',
                    'TIMESTAMP(x) WITH LOCAL TIME ZONE',
                    'TIMESTAMP(x) WITH TIME ZONE', 'TIMESTAMP(x)', 'UNDEFINED',
                    'UROWID', 'VARCHAR(x)', 'VARCHAR2', 'XMLTYPE'
                )
                AND data_type_owner NOT IN ('MDSYS')
                THEN 1
                ELSE 0
            END
        ) AS "USER_DEFINED_COL_COUNT"
    FROM (
        SELECT
            &s_a_con_id. AS con_id,
            a.owner,
            table_name,
@sql/extracts/&s_data_type_exp.
            data_type,
            data_type_owner,
            1 AS col_count
        FROM &s_tblprefix._tab_columns a
        INNER JOIN &s_tblprefix._objects b
            ON &s_a_con_id. = &s_b_con_id.
            AND a.owner = b.owner
            AND a.table_name = b.object_name
            AND b.object_type = 'TABLE'
        WHERE a.owner NOT IN
@sql/extracts/exclude_schemas.sql
    )
    GROUP BY
        con_id,
        owner,
        table_name
),
vexttab AS (
    SELECT
        &s_a_con_id. AS con_id,
        owner,
        table_name,
        type_owner,
        type_name,
        default_directory_owner,
        default_directory_name
    FROM &s_tblprefix._external_tables a
),
vsrc AS (
    SELECT
        src.con_id,
        src.owner,
        src.name,
        src.type,
        trigger_type,
        triggering_event,
        base_object_type,
        SUM(nr_lines) AS sum_nr_lines,
        COUNT(1) AS qt_objs,
        SUM(count_utl) AS sum_nr_lines_w_utl,
        SUM(count_dbms) AS sum_nr_lines_w_dbms,
        SUM(count_exec_im) AS count_exec_im,
        SUM(count_dbms_sql) AS count_dbms_sql,
        SUM(count_dbms_utl) AS sum_nr_lines_w_dbms_utl
    FROM (
        SELECT
            &s_a_con_id. AS con_id,
            a.owner,
            a.name,
            a.type,
            MAX(a.line) AS nr_lines,
            COUNT(
                CASE
                    WHEN LOWER(a.text) LIKE '%utl_%'
                    THEN 1
                END
            ) AS count_utl,
            COUNT(
                CASE
                    WHEN LOWER(a.text) LIKE '%dbms_%'
                    THEN 1
                END
            ) AS count_dbms,
            COUNT(
                CASE
                    WHEN LOWER(a.text) LIKE '%dbms_%' AND LOWER(a.text) LIKE '%utl_%'
                    THEN 1
                END
            ) AS count_dbms_utl,
            COUNT(
                CASE
                    WHEN LOWER(a.text) LIKE '%execute%immediate%'
                    THEN 1
                END
            ) AS count_exec_im,
            COUNT(
                CASE
                    WHEN LOWER(a.text) LIKE '%dbms_sql%'
                    THEN 1
                END
            ) AS count_dbms_sql
        FROM &s_tblprefix._source a
        GROUP BY
            &s_a_con_id.,
            a.owner,
            a.name,
            a.type
    ) src
    LEFT JOIN &s_tblprefix._triggers t
           ON &s_t_con_id. = src.con_id
          AND t.owner = src.owner
          AND t.trigger_name = src.name
    WHERE
        (
             t.trigger_name IS NULL
         AND src.owner NOT IN
@sql/extracts/exclude_schemas.sql
        )
        OR (
                t.base_object_type IN ('DATABASE', 'SCHEMA')
            AND t.status = 'ENABLED'
            AND (t.owner, t.trigger_name) NOT IN (
                ('SYS', 'XDB_PI_TRIG'),
                ('SYS', 'DELETE_ENTRIES'),
                ('SYS', 'OJDS$ROLE_TRIGGER'),
                ('SYS', 'DBMS_SET_PDB'),
                ('MDSYS', 'SDO_TOPO_DROP_FTBL'),
                ('MDSYS', 'SDO_GEOR_BDDL_TRIGGER'),
                ('MDSYS', 'SDO_GEOR_ADDL_TRIGGER'),
                ('MDSYS', 'SDO_NETWORK_DROP_USER'),
                ('MDSYS', 'SDO_ST_SYN_CREATE'),
                ('MDSYS', 'SDO_DROP_USER'),
                ('GSMADMIN_INTERNAL', 'GSMLOGOFF'),
                ('SYSMAN', 'MGMT_STARTUP'),
                ('SYS', 'AW_TRUNC_TRG'),
                ('SYS', 'AW_REN_TRG'),
                ('SYS', 'AW_DROP_TRG')
            )
        )
    GROUP BY
        src.con_id,
        src.owner,
        src.name,
        src.type,
        t.trigger_type,
        t.triggering_event,
        t.base_object_type
),
vidxtype AS (
    SELECT
        &s_a_con_id. AS con_id,
        a.owner,
        a.index_type,
        a.uniqueness,
        a.compression,
        a.partitioned,
        a.temporary,
        a.secondary,
        &s_index_visibility. AS visibility,
        a.join_index,
        CASE WHEN a.ityp_owner IS NOT NULL THEN 'Y' ELSE 'N' END AS custom_index_type,
        a.table_name,
        a.index_name
    FROM &s_tblprefix._indexes a
    WHERE owner NOT IN
@sql/extracts/exclude_schemas.sql
),
vseg AS (
    SELECT
        &s_a_con_id. AS con_id,
        a.owner,
        a.segment_name,
        ROUND(SUM(a.bytes) / 1024 / 1024, 3) AS segment_mb,
        SUM(CASE WHEN tablespace_name = 'SYSTEM' THEN 1 ELSE 0 END) AS segments_in_system_ts
    FROM &s_tblprefix._segments a
    GROUP BY
        &s_a_con_id.,
        a.owner,
        a.segment_name
),
vtabcons AS (
    SELECT
        con_id,
        owner,
        table_name,
        SUM(pk) AS pk,
        SUM(uk) AS uk,
        SUM(ck) AS ck,
        SUM(ri) AS ri,
        SUM(vwck) AS vwck,
        SUM(vwro) AS vwro,
        SUM(hashexpr) AS hashexpr,
        SUM(refcolcons) AS refcolcons,
        SUM(suplog) AS suplog,
        COUNT(1) AS total_cons
    FROM (
        SELECT
            &s_a_con_id. AS con_id,
            a.owner,
            a.table_name,
            DECODE(b.constraint_type, 'P', 1, NULL) AS pk,
            DECODE(b.constraint_type, 'U', 1, NULL) AS uk,
            DECODE(b.constraint_type, 'C', 1, NULL) AS ck,
            DECODE(b.constraint_type, 'R', 1, NULL) AS ri,
            DECODE(b.constraint_type, 'V', 1, NULL) AS vwck,
            DECODE(b.constraint_type, 'O', 1, NULL) AS vwro,
            DECODE(b.constraint_type, 'H', 1, NULL) AS hashexpr,
            DECODE(b.constraint_type, 'F', 1, NULL) AS refcolcons,
            DECODE(b.constraint_type, 'S', 1, NULL) AS suplog
        FROM &s_tblprefix._tables a
        LEFT OUTER JOIN &s_tblprefix._constraints b
                     ON &s_a_con_id. = &s_b_con_id.
                    AND a.owner = b.owner
                    AND a.table_name = b.table_name
        WHERE a.owner NOT IN
@sql/extracts/exclude_schemas.sql
    )
    GROUP BY
        con_id,
        owner,
        table_name
),
nncols AS (
    SELECT
        &s_a_con_id. AS con_id,
        owner,
        table_name,
        COUNT(1) AS nn_count
    FROM &s_tblprefix._tab_columns a
    WHERE
        nullable = 'N'
        AND owner NOT IN
@sql/extracts/exclude_schemas.sql
    GROUP BY
        &s_a_con_id,
        owner,
        table_name
)
SELECT
    :v_pkey AS pkey,
    -- Objects
    vobj.con_id,
    vobj.owner,
    vobj.object_name,
    vobj.object_type,
    vobj.status,
    -- Tables
    ti.partitioned,
    ti.iot_type,
    ti.nested,
    ti.temporary,
    ti.secondary,
    ti.clustered_table,
    ti.object_table,
    ti.xml_table,
    CASE WHEN ext.table_name IS NOT NULL THEN 'Y' ELSE 'N' END AS is_external_table,
    p.partitioning_type,
    p.subpartitioning_type,
    p.partition_count,
    sp.cnt AS subpartition_count,
    -- Mviews
    mv.updatable,
    mv.rewrite_enabled,
    mv.refresh_mode,
    mv.refresh_method,
    mv.fast_refreshable,
    mv.compile_state,
    -- Column types
    ct.ANYDATA_COL_COUNT,
    ct.BFILE_COL_COUNT,
    ct.BINARY_DOUBLE_COL_COUNT,
    ct.BINARY_FLOAT_COL_COUNT,
    ct.BLOB_COL_COUNT,
    ct.CFILE_COL_COUNT,
    ct.CHAR_COL_COUNT,
    ct.CLOB_COL_COUNT,
    ct.DATE_COL_COUNT,
    ct.FLOAT_COL_COUNT,
    ct.INTERVAL_DAY_TO_SECOND_COL_COU,
    ct.INTERVAL_YEAR_TO_MONTH_COL_COU,
    ct.JSON_COL_COUNT,
    ct.LONG_RAW_COL_COUNT,
    ct.LONG_COL_COUNT,
    ct.MLSLABEL_COL_COUNT,
    ct.NCHAR_VARYING_COL_COUNT,
    ct.NCHAR_COL_COUNT,
    ct.NCLOB_COL_COUNT,
    ct.NUMBER_COL_COUNT,
    ct.NVARCHAR2_COL_COUNT,
    ct.RAW_COL_COUNT,
    ct.ROWID_COL_COUNT,
    ct.SPATIAL_COL_COUNT,
    ct.TIME_WITH_TIME_ZONE_COL_COUNT,
    ct.TIME_COL_COUNT,
    ct.TIMESTAMP_WITH_LOCAL_TIME_Z_CO,
    ct.TIMESTAMP_WITH_TIME_ZONE_COL_C,
    ct.TIMESTAMP_COL_COUNT,
    ct.UROWID_COL_COUNT,
    ct.VARCHAR_COL_COUNT,
    ct.VARCHAR2_COL_COUNT,
    ct.XMLTYPE_COL_COUNT,
    ct.UNDEFINED_COL_COUNT,
    ct.USER_DEFINED_COL_COUNT,
    -- Source code
    vsrc.sum_nr_lines,
    vsrc.sum_nr_lines_w_utl,
    vsrc.sum_nr_lines_w_dbms,
    vsrc.count_exec_im,
    vsrc.count_dbms_sql,
    vsrc.sum_nr_lines_w_dbms_utl,
    vsrc.trigger_type,
    vsrc.triggering_event,
    vsrc.base_object_type,
    -- Indexs
    vi.index_type,
    vi.uniqueness AS index_uniqueness,
    vi.compression AS index_compression,
    vi.partitioned AS index_partitioned,
    vi.temporary AS index_temporary,
    vi.secondary AS index_secondary,
    vi.visibility AS index_visibility,
    vi.join_index AS index_join_index,
    vi.custom_index_type AS index_custom_index_type,
    vi.table_name AS index_table_name,
    vs.segment_mb,
    vs.segments_in_system_ts,
    -- Constraints
    vtabcons.pk AS primary_key_count,
    vtabcons.uk AS unique_cons_count,
    /* Attempt to aproximate number of check constraints that are more than just 'NOT NULL' by
       subtracting the number of non-nullable columns from the number of check constraints.
       Multicolumn primary keys will throw this off, so we use a floor of zero.  */
    GREATEST(vtabcons.ck - (NVL(nncols.nn_count, 0) - NVL(vtabcons.pk, 0)), 0) AS check_cons_count,
    vtabcons.ri AS foreign_key_cons_count,
    vtabcons.vwck AS view_check_cons_count,
    vtabcons.vwro AS view_read_only_count,
    vtabcons.hashexpr AS hash_expr_count,
    vtabcons.refcolcons,
    vtabcons.suplog AS supplemental_logging_count,
    nncols.nn_count AS nnull_cons_count,
    :v_dma_source_id AS dma_source_id,
    :v_manual_unique_id AS dma_manual_id
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
            AND vobj.object_type LIKE '%INDEX%'
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
