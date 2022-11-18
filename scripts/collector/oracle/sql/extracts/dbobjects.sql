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
spool &outputdir/opdb__dbobjects__&v_tag

WITH 
vdbobji AS (
        SELECT
               &v_a_con_id AS con_id,
               owner,
               object_type,
               &v_editionable_col AS editionable
        FROM &v_tblprefix._objects a
        WHERE  owner NOT IN
@&EXTRACTSDIR/exclude_schemas.sql
),       
vdbobj AS (
        SELECT '&&v_host'
               || '_'
               || '&&v_dbname'
               || '_'
               || '&&v_hora' AS pkey,
               con_id,
               owner,
               object_type,
               editionable,
               COUNT(1)              count
        FROM vdbobji
        GROUP  BY  con_id, owner, editionable , object_type
)
SELECT pkey , 
       con_id , 
       owner , 
       object_type , 
       editionable ,
       count  
FROM vdbobj a;
spool off

