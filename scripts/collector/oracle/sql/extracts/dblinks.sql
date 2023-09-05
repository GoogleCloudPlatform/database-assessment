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
spool &outputdir/opdb__dblinks__&v_tag
prompt PKEY|CON_ID|OWNER|COUNT|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vdbl AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id,
       owner,
       count(1) count
FROM   &v_tblprefix._db_links a
WHERE username IS NOT NULL
GROUP BY '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora',
       &v_a_con_id , owner)
SELECT pkey , con_id , owner , count,
       '&v_dma_source_id' AS DMA_SOURCE_ID, chr(39) || '&v_collectionTag' || chr(39) AS DMA_MANUAL_ID
FROM vdbl;
spool off
