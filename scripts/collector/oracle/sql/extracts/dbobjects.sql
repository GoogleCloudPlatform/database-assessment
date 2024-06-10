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
COLUMN EDITIONABLE FORMAT A11

spool &outputdir/opdb__dbobjects__&v_tag
prompt PKEY|CON_ID|OWNER|OBJECT_TYPE|EDITIONABLE|COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
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
vdbobj AS (
        SELECT :v_pkey AS pkey,
               i.con_id,
               i.owner,
               i.object_type,
               i.editionable,
               COUNT(1)              count
        FROM vdbobji i
        LEFT OUTER JOIN vdbobjx x ON i.object_type = x.object_type AND i.owner = x.owner AND i.object_name = x.synonym_name AND i.con_id = x.con_id
        WHERE (CASE WHEN i.object_type = 'SYNONYM' and i.owner ='PUBLIC' and ( i.object_name like '/%' OR x.table_owner IS NOT NULL) THEN 0 ELSE 1 END = 1)
        AND i.object_name NOT LIKE 'BIN$%'
        GROUP  BY  i.con_id, i.owner, i.editionable , i.object_type
)
SELECT pkey ,
       con_id ,
       owner ,
       object_type ,
       editionable ,
       count  ,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vdbobj a;
spool off
