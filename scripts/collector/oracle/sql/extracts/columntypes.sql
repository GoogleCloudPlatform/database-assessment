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
spool &outputdir/opdb__columntypes__&v_tag

WITH coltypes AS (
SELECT
    *
FROM
    ( SELECT 
    con_id,
    owner, table_name, col_count, 
    case when data_type not in (
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
        'XMLTYPE',
        'UNDEFINED'
    )
      AND data_type_owner NOT IN ('MDSYS')
    THEN 'USER_DEFINED' ELSE CASE WHEN data_type_owner ='MDSYS' THEN 'SPATIAL' ELSE data_type END 
    END as data_type
      FROM (
        SELECT
            &v_a_con_id AS con_id,
            owner,
            table_name,
            regexp_replace(data_type, '\([[:digit:]]\)', '(x)') AS data_type,
            data_type_owner,
            1                                                 AS col_count
        FROM
            &v_tblprefix._tab_columns a
        WHERE
            owner NOT IN (
                SELECT
                    name
                FROM
                    system.logstdby$skip_support
                WHERE
                    action = 0
            ) )
    ) PIVOT (
        SUM(col_count)
    AS col_count
        FOR data_type
        IN ( 
         'ANYDATA' AS                               "ANYDATA",
         'BFILE' AS                                 "BFILE",
         'BINARY_DOUBLE' AS                         "BINARY_DOUBLE",
         'BINARY_FLOAT' AS                          "BINARY_FLOAT",
         'BLOB' AS                                  "BLOB",
         'CFILE' AS                                 "CFILE",
         'CHAR' AS                                  "CHAR",
         'CLOB' AS                                  "CLOB",
         'DATE' AS                                  "DATE",
         'FLOAT' AS                                 "FLOAT",
         'INTERVAL DAY(x) TO SECOND(x)' AS          "INTERVAL_DAY_TO_SECOND",
         'INTERVAL YEAR(x) TO MONTH' AS             "INTERVAL_YEAR_TO_MONTH",
         'JSON'  AS                                 "JSON" ,
         'LONG RAW' AS                              "LONG_RAW",
         'LONG' AS                                  "LONG",
         'MLSLABEL' AS                              "MLSLABEL",
         'NCHAR VARYING' AS                         "NCHAR_VARYING",
         'NCHAR' AS                                 "NCHAR",
         'NCLOB' AS                                 "NCLOB",
         'NUMBER' AS                                "NUMBER",
         'NVARCHAR2' AS                             "NVARCHAR2",
         'RAW' AS                                   "RAW",
         'ROWID' AS                                 "ROWID",
         'SPATIAL' AS                               "SPATIAL",
         'TIME(x) WITH TIME ZONE' AS                "TIME_WITH_TIME_ZONE",
         'TIME(x)' AS                               "TIME",
         'TIMESTAMP(x) WITH LOCAL TIME ZONE' AS     "TIMESTAMP_WITH_LOCAL_TIME_Z",
         'TIMESTAMP(x) WITH TIME ZONE' AS           "TIMESTAMP_WITH_TIME_ZONE",
         'TIMESTAMP(x)' AS                          "TIMESTAMP",
         'UROWID' AS                                "UROWID",
         'VARCHAR(x)' AS                            "VARCHAR",
         'VARCHAR2' AS                              "VARCHAR2",
         'XMLTYPE' AS                               "XMLTYPE",
         'UNDEFINED' AS                             "UNDEFINED",
         'USER_DEFINED' AS                          "USER_DEFINED"
        )
    )
),
segs AS (
SELECT
    &v_a_con_id AS con_id,
    owner,
    segment_name,
    SUM(bytes) as bytes
FROM
    &v_tblprefix._segments a
WHERE
    owner NOT IN (
        SELECT
            name
        FROM
            system.logstdby$skip_support
        WHERE
            action = 0
    )
GROUP BY
    &v_a_con_id,
    owner,
    segment_name)
SELECT
    '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
    c.*, s.bytes
FROM  coltypes c 
JOIN segs s ON c.con_id = s.con_id and s.owner = c.owner and s.segment_name = c.table_name 
ORDER BY 1,2,3
;

spool off
