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
exec dbms_application_info.set_action('exttab');
spool &outputdir./opdb__exttab__&s_tag.
prompt PKEY|CON_ID|OWNER|TABLE_NAME|TYP|TYPE_NAME|DEF|DEFAULT_DIRECTORY_NAME|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vexttab AS (
SELECT :v_pkey AS pkey,
       &s_a_con_id. as con_id, owner, table_name, type_owner, type_name, default_directory_owner, default_directory_name
FROM &s_tblprefix._external_tables a)
SELECT pkey , con_id , owner , table_name , type_owner , type_name ,
       default_directory_owner , default_directory_name,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vexttab;
spool off
