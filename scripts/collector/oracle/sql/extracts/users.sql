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
spool &outputdir/opdb__users__&v_tag
prompt PKEY|CON_ID|USERNAME|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vuser AS (
SELECT :v_pkey AS pkey,
       &v_a_con_id AS con_id,
       username
FROM   &v_tblprefix._users a
ORDER  BY username)
SELECT pkey , con_id, username,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vuser;
spool off
