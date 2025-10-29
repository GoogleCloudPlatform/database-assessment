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
spool &outputdir/opdb__dbinstances__&v_tag
prompt PKEY|INST_ID|INSTANCE_NAME|HOST_NAME|VERSION|STATUS|DATABASE_STATUS|INSTANCE_ROLE|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH vdbinst as (
SELECT :v_pkey AS pkey,
       inst_id,
       instance_name,
       host_name,
       version,
       status,
       database_status,
       instance_role
FROM   gv$instance )
SELECT pkey , inst_id , instance_name , host_name ,
       version , status , database_status , instance_role,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vdbinst;
spool off
