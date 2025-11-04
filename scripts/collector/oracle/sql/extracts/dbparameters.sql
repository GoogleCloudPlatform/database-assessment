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
exec dbms_application_info.set_action('dbparameters');




WITH vparam AS (
SELECT :v_pkey AS pkey,
       inst_id,
       &s_a_con_id. AS con_id,
       replace(name, chr(39), chr(34)) AS name,
       TRANSLATE(SUBSTR(value, 1, 60), chr(124)||chr(10)||chr(13)||chr(39), ' ') AS value,
       TRANSLATE(SUBSTR(&s_dbparam_dflt_col., 1, 30), chr(124)||chr(10)||chr(13)||chr(39), ' ') AS default_value,
       isdefault
FROM   gv$system_parameter a
ORDER  BY 2,3 )
SELECT pkey || '|' || 
       inst_id || '|' || 
       con_id || '|' || 
       name || '|' || 
       value || '|' || 
       default_value || '|' || 
       isdefault || '|' || 
       :v_dma_source_id || '|' || --dma_source_id 
       :v_manual_unique_id --dma_manual_id
FROM vparam;


