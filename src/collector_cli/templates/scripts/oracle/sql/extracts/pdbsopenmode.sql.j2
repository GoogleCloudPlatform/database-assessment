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
spool &outputdir/opdb__pdbsopenmode__&v_tag
prompt PKEY|CON_ID|NAME|OPEN_MODE|TOTAL_GB|CON_UID|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vpdbmode as (
SELECT :v_pkey AS pkey,
       con_id,
       name,
       open_mode,
       total_size / 1024 / 1024 / 1024 TOTAL_GB,
       con_uid
FROM   v$pdbs )
SELECT pkey , con_id , name , open_mode , TOTAL_GB, con_uid,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vpdbmode;
spool off
