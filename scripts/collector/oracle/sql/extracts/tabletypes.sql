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
COLUMN TEMPORARY FORMAT A20
COLUMN SECONDARY FORMAT A20
COLUMN NESTED    FORMAT A20
COLUMN CLUSTERED_TABLE FORMAT A20
spool &outputdir/opdb__tabletypes__&v_tag

WITH tblinfo AS (
SELECT
    &v_a_con_id AS con_id,
    a.owner,
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
    COUNT(1) AS table_count
FROM &v_tblprefix._tables a
WHERE a.owner NOT IN (
        SELECT name
        FROM system.logstdby$skip_support
        WHERE action = 0
       )  
GROUP BY
    &v_a_con_id,
    a.owner,
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
    END
)
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       con_id,
       owner,
       partitioned,
       iot_type,
       nested,
       temporary,
       secondary,
       clustered_table,
       table_count
FROM  tblinfo;
spool off
COLUMN TEMPORARY CLEAR
COLUMN SECONDARY CLEAR
COLUMN NESTED CLEAR
COLUMN CLUSTERED_TABLE CLEAR
