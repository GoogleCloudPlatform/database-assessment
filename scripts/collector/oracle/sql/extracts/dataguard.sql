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
exec dbms_application_info.set_action('dataguard');
















WITH vodg AS (
SELECT  :v_pkey AS pkey,
        &s_a_con_id. as con_id, inst_id,
        dest_id,
        dest_name,
        REPLACE(destination ,'|', ' ')destination,
        status,
        REPLACE(target  ,'|', ' ')target,
        schedule,
        register,
        REPLACE(alternate  ,'|', ' ')alternate,
        transmit_mode,
        affirm,
        &s_dg_valid_role. AS valid_role,
        &s_dg_verify.     AS verify,
        'N/A' as log_archive_config
FROM gv$archive_dest a
WHERE destination IS NOT NULL)
SELECT pkey , con_id , inst_id , log_archive_config , dest_id , dest_name , destination , status ,
       target , schedule , register , alternate ,
       transmit_mode , affirm , valid_role , verify,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM vodg;















