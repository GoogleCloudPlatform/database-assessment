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
spool &outputdir/opdb__dbobjectnames__&v_tag

WITH 
vdbobji AS (
        SELECT
               &v_a_con_id AS con_id,
               owner,
               object_type,
               &v_editionable_col AS editionable,
               object_name
        FROM &v_tblprefix._objects a
        WHERE  (owner = 'SYS' AND object_type = 'DIRECTORY')
           OR owner NOT IN
@&EXTRACTSDIR/exclude_schemas.sql
),
vdbobjx AS (
        SELECT 'SYNONYM' as object_type, owner, synonym_name  ,  &v_b_con_id AS con_id, table_owner
        FROM &v_tblprefix._synonyms b
        WHERE owner = 'PUBLIC' and 
              table_owner in 
@&EXTRACTSDIR/exclude_schemas.sql
              ),
vsrc   AS (SELECT 
                  &v_c_con_id AS con_id, 
                  owner,
                  name,
                  type,
                  max(line) as lines
           FROM  &v_tblprefix._source  c
           WHERE owner NOT IN (
@&EXTRACTSDIR/exclude_schemas.sql
           )
           GROUP BY &v_c_con_id , owner, name, type
),
vdbobj AS (
        SELECT /*+ USE_HASH(i x s) */
               '&&v_host'
               || '_'
               || '&&v_dbname'
               || '_'
               || '&&v_hora' AS pkey,
               i.con_id,
               i.owner,
               i.object_name,
               i.object_type,
               i.editionable,
               s.lines
        FROM vdbobji i
        LEFT OUTER JOIN vdbobjx x ON i.object_type = x.object_type AND i.owner = x.owner AND i.object_name = x.synonym_name AND i.con_id = x.con_id
        LEFT OUTER JOIN vsrc s    ON i.object_type = s.type AND i.owner = s.owner AND i.object_name = s.name AND i.con_id = s.con_id
        WHERE NOT ( i.object_type = 'SYNONYM' AND i.owner ='PUBLIC' AND ( i.object_name LIKE '/%' OR x.table_owner IS NOT NULL OR x.table_owner ='SYS') )
        AND i.object_name NOT LIKE 'BIN$%'
)
SELECT pkey , 
       con_id , 
       owner , 
       object_name, 
       object_type , 
       editionable ,
       lines
FROM vdbobj a;
spool off

