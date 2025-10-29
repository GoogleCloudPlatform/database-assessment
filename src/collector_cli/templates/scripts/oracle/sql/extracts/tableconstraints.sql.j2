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
spool &outputdir/opdb__tableconstraints__&v_tag
prompt PKEY|CON_ID|OWNER|TABLE_NAME|PK|UK|CK|RI|VWCK|VWRO|HASHEXPR|SUPLOG|TOTAL_CONS|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vnopk AS (
SELECT :v_pkey AS pkey,
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
       SUM(suplog)                suplog,
       COUNT(1)                   total_cons
FROM   (SELECT &v_a_con_id AS con_id,
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
        FROM   &v_tblprefix._tables a
               left outer join &v_tblprefix._constraints b
                            ON &v_a_con_id = &v_b_con_id
                               AND a.owner = b.owner
                               AND a.table_name = b.table_name
        WHERE a.owner NOT IN
@&EXTRACTSDIR/exclude_schemas.sql
       )
GROUP  BY :v_pkey,
          con_id,
          owner,
          table_name)
SELECT pkey , con_id , owner ,table_name , pk , uk , ck ,
       ri , vwck , vwro , hashexpr , suplog , total_cons,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vnopk;
spool off
