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
spool &outputdir/opdb__dbhwmarkstatistics__&v_tag
prompt PKEY|DESCRIPTION|HIGHWATER|LAST_VALUE|CON_ID|DMA_SOURCE_ID|DMA_MANUAL_ID

WITH vhwmst AS (
SELECT :v_pkey AS pkey,
       description,
       highwater,
       last_value,
       &v_a_con_id AS con_id
FROM   &v_tblprefix._high_water_mark_statistics a
ORDER  BY description)
SELECT pkey , description , highwater , last_value, con_id,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vhwmst;
spool off
