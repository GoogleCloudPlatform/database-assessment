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
exec dbms_application_info.set_action('mviewtypes');








WITH mvinfo AS (
SELECT
    &s_a_con_id. AS con_id,
    a.owner,
    a.updatable,
    a.rewrite_enabled,
    a.refresh_mode,
    a.refresh_method,
    a.fast_refreshable,
    a.compile_state
FROM &s_tblprefix._mviews a
WHERE a.owner NOT IN (
@sql/extracts/exclude_schemas.sql
       )
)
SELECT :v_pkey AS pkey,
       con_id,
       owner,
       updatable,
       rewrite_enabled,
       refresh_mode,
       refresh_method,
       fast_refreshable,
       compile_state,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM  mvinfo;







