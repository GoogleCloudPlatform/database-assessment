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

spool &outputdir/opdb__opatch__&v_tag
column c_patchinfo new_value p_patchinfo noprint

variable v_patchinfo VARCHAR2(500);
DECLARE
  cnt NUMBER;
BEGIN
  SELECT count(1) INTO cnt FROM all_objects WHERE object_name = 'DBMS_QOPATCH';
  IF cnt = 1 THEN
    :v_patchinfo := 'sys.dbms_qopatch.get_opatch_lsinventory';
  ELSE
    :v_patchinfo := 'xmltype(' || chr(39) || '<InventoryInstance>
<patches>
<patch>
<patchID>0</patchID>
<uniquePatchID>0</uniquePatchID>
<patchDescription>No Data</patchDescription>
<patchType>NA</patchType>
<appliedDate>NA</appliedDate>
</patch>
</patches>
</InventoryInstance>' || chr(39) ||')' ;
  END IF;
END;
/

SELECT :v_patchinfo
 AS c_patchinfo FROM dual;



WITH xml AS (
SELECT  &p_patchinfo
        AS x
    FROM
        dual ),
vopatch as (
    SELECT
        extractvalue(column_value, '/patch/patchID')               patch_id,
        extractvalue(column_value, '/patch/uniquePatchID')         unique_patch_id,
        extractvalue(column_value, '/patch/patchDescription')      patch_descr,
        extractvalue(column_value, '/patch/patchType')             patch_type,
        extractvalue(column_value, '/patch/appliedDate')             applied_date,
        extractvalue(column_value, '/patch/bugs[1]/bug[1]/description[1]')      bug_descr
    FROM
        xml                                                             x,
        TABLE ( xmlsequence(extract(x.x, '/InventoryInstance/patches/*')) )              rws
        order by 1
)
SELECT :v_pkey AS pkey,
       patch_id, unique_patch_id, patch_type, applied_date, patch_descr, bug_descr,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vopatch;
spool off
