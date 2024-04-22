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

COLUMN INTERVAL_DAY_TO_SECOND_COL_COU HEADING INTERVAL_DAY_TO_SECOND_COL_COUNT FORMAT 9999999999999999999999999999999
COLUMN INTERVAL_YEAR_TO_MONTH_COL_COU HEADING INTERVAL_YEAR_TO_MONTH_COL_COUNT FORMAT 9999999999999999999999999999999
COLUMN TIMESTAMP_WITH_LOCAL_TIME_Z_CO HEADING TIMESTAMP_WITH_LOCAL_TIME_Z_COUNT FORMAT 9999999999999999999999999999999
COLUMN TIMESTAMP_WITH_TIME_ZONE_COL_C HEADING TIMESTAMP_WITH_TIME_ZONE_COL_COUNT FORMAT 9999999999999999999999999999999

spool &outputdir/opdb__columntypes__&v_tag
prompt PKEY|CON_ID|OWNER|TABLE_NAME|ANYDATA_COL_COUNT|BFILE_COL_COUNT|BINARY_DOUBLE_COL_COUNT|BINARY_FLOAT_COL_COUNT|BLOB_COL_COUNT|CFILE_COL_COUNT|CHAR_COL_COUNT|CLOB_COL_COUNT|DATE_COL_COUNT|FLOAT_COL_COUNT|INTERVAL_DAY_TO_SECOND_COL_COUNT|INTERVAL_YEAR_TO_MONTH_COL_COUNT|JSON_COL_COUNT|LONG_RAW_COL_COUNT|LONG_COL_COUNT|MLSLABEL_COL_COUNT|NCHAR_VARYING_COL_COUNT|NCHAR_COL_COUNT|NCLOB_COL_COUNT|NUMBER_COL_COUNT|NVARCHAR2_COL_COUNT|RAW_COL_COUNT|ROWID_COL_COUNT|SPATIAL_COL_COUNT|TIME_WITH_TIME_ZONE_COL_COUNT|TIME_COL_COUNT|TIMESTAMP_WITH_LOCAL_TIME_Z_COUNT|TIMESTAMP_WITH_TIME_ZONE_COL_COUNT|TIMESTAMP_COL_COUNT|UROWID_COL_COUNT|VARCHAR_COL_COUNT|VARCHAR2_COL_COUNT|XMLTYPE_COL_COUNT|UNDEFINED_COL_COUNT|USER_DEFINED_COL_COUNT|BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH coltypes AS (
  SELECT
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
        SELECT /*+ USE_HASH(b a) NOPARALLEL */
            &v_a_con_id AS con_id,
            a.owner,
            table_name,
@&EXTRACTSDIR/&v_data_type_exp
            AS data_type,
            data_type_owner,
            1                                                 AS col_count
        FROM
            &v_tblprefix._tab_columns a INNER JOIN &v_tblprefix._objects b ON &v_a_con_id = &v_b_con_id AND a.owner = b.owner AND a.table_name = b.object_name and b.object_type = 'TABLE'
        WHERE
            a.owner NOT IN
@&EXTRACTSDIR/exclude_schemas.sql
           )
   GROUP BY
    con_id, owner, table_name
)
SELECT
    :v_pkey AS pkey,
    c.con_id,
    c.owner,
    c.table_name,
    c.ANYDATA_COL_COUNT                          ,
    c.BFILE_COL_COUNT                            ,
    c.BINARY_DOUBLE_COL_COUNT                    ,
    c.BINARY_FLOAT_COL_COUNT                     ,
    c.BLOB_COL_COUNT                             ,
    c.CFILE_COL_COUNT                            ,
    c.CHAR_COL_COUNT                             ,
    c.CLOB_COL_COUNT                             ,
    c.DATE_COL_COUNT                             ,
    c.FLOAT_COL_COUNT                            ,
    c.INTERVAL_DAY_TO_SECOND_COL_COU             ,
    c.INTERVAL_YEAR_TO_MONTH_COL_COU             ,
    c.JSON_COL_COUNT                             ,
    c.LONG_RAW_COL_COUNT                         ,
    c.LONG_COL_COUNT                             ,
    c.MLSLABEL_COL_COUNT                         ,
    c.NCHAR_VARYING_COL_COUNT                    ,
    c.NCHAR_COL_COUNT                            ,
    c.NCLOB_COL_COUNT                            ,
    c.NUMBER_COL_COUNT                           ,
    c.NVARCHAR2_COL_COUNT                        ,
    c.RAW_COL_COUNT                              ,
    c.ROWID_COL_COUNT                            ,
    c.SPATIAL_COL_COUNT                          ,
    c.TIME_WITH_TIME_ZONE_COL_COUNT              ,
    c.TIME_COL_COUNT                             ,
    c.TIMESTAMP_WITH_LOCAL_TIME_Z_CO             ,
    c.TIMESTAMP_WITH_TIME_ZONE_COL_C             ,
    c.TIMESTAMP_COL_COUNT                        ,
    c.UROWID_COL_COUNT                           ,
    c.VARCHAR_COL_COUNT                          ,
    c.VARCHAR2_COL_COUNT                         ,
    c.XMLTYPE_COL_COUNT                          ,
    c.UNDEFINED_COL_COUNT                        ,
    c.USER_DEFINED_COL_COUNT                     ,
    0 as bytes                                   ,
    :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM  coltypes c
ORDER BY 1,2,3,4
;

spool off

COLUMN INTERVAL_DAY_TO_SECOND_COL_COU CLEAR
COLUMN INTERVAL_YEAR_TO_MONTH_COL_COU CLEAR
COLUMN TIMESTAMP_WITH_LOCAL_TIME_Z_CO CLEAR
COLUMN TIMESTAMP_WITH_TIME_ZONE_COL_C CLEAR
