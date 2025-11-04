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
exec dbms_application_info.set_action('backups');


SELECT :v_pkey || '|' || --pkey
       TRUNC(start_time) || '|' || --backup_start_date
       &s_a_con_id. || '|' || --con_id
       input_type || '|' ||
       ROUND(SUM(elapsed_seconds)) || '|' || --elapsed_seconds
       ROUND(SUM(input_bytes)/1024/1024) || '|' || --mbytes_in
       ROUND(SUM(output_bytes)/1024/1024) || '|' || --mbytes_out
       :v_dma_source_id || '|' || --dma_source_id
       :v_manual_unique_id  --dma_manual_id
FROM v$rman_backup_job_details a
WHERE start_time >= TRUNC(sysdate) - :v_statsWindow
GROUP BY TRUNC(start_time), input_type, &s_a_con_id.
;

