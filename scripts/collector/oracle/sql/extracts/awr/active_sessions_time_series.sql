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
exec dbms_application_info.set_action('sessions_on_cpu');

WITH vsrcconn AS (
SELECT :v_pkey AS pkey,
       has.dbid,
       has.instance_number,
       dhsnap.begin_interval_time,
       count(1) sessions_on_cpu_or_resmgr,
       sum(case when session_state = 'ON CPU' then 1 else 0 end) as sessions_on_cpu,
       sum(case when event = 'resmgr:cpu quantum' then 1 else 0 end) as sessions_on_res_mgr
FROM &s_tblprefix._HIST_ACTIVE_SESS_HISTORY has
     INNER JOIN &s_tblprefix._HIST_SNAPSHOT dhsnap
             ON has.snap_id = dhsnap.snap_id
            AND has.instance_number = dhsnap.instance_number
            AND has.dbid = dhsnap.dbid
WHERE has.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
  AND has.dbid = :v_dbid
  AND (session_state = 'ON CPU' or event = 'resmgr:cpu quantum')
GROUP BY 
       :v_pkey ,
       has.dbid,
       has.instance_number,
       dhsnap.begin_interval_time
)
SELECT pkey  || '|' ||  
       dbid  || '|' || 
       instance_number  || '|' ||  
       begin_interval_time|| '|' ||  
       sessions_on_cpu_or_resmgr || '|' || 
       sessions_on_cpu || '|' || 
       sessions_on_res_mgr || '|' || 
       :v_dma_source_id || '|' || --dma_source_id
       :v_manual_unique_id --dma_manual_id
FROM vsrcconn
;

