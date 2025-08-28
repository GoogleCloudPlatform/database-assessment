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
exec dbms_application_info.set_action('archlogs');


SELECT :v_pkey AS pkey,
       TRUNC(first_Time) AS log_start_date,
       TO_CHAR(first_time, 'HH24') AS hour,
       thread# AS thread_num,
       dest_id,
       COUNT(1) AS cnt,
       ROUND(SUM(blocks * block_size)/1024/1024) AS mbytes,
       :v_dma_source_id AS dma_source_id, 
       :v_manual_unique_id AS dma_manual_id
FROM gv$archived_log
WHERE first_time >= TRUNC(sysdate) - :v_statsWindow
GROUP BY TRUNC(first_time), thread#, TO_CHAR(first_time, 'HH24'), dest_id
;

