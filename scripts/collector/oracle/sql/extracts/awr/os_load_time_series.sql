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
exec dbms_application_info.set_action('awrhistosstat');


WITH vossummary
     AS (SELECT s.dbid,
                s.instance_number,
                snap.begin_interval_time,
                sum(case when s.stat_name = 'NUM_CPU_CORES' then s.value else 0 end) as num_cpu_cores,
                sum(case when s.stat_name = 'LOAD' then s.value else 0 end) as os_load
         FROM &s_tblprefix._hist_osstat s
              INNER JOIN &s_tblprefix._hist_snapshot snap
                     ON s.snap_id = snap.snap_id
                     AND s.instance_number = snap.instance_number
                     AND s.dbid = snap.dbid
         WHERE s.snap_id BETWEEN :v_min_snapid AND :v_max_snapid
         AND s.dbid = :v_dbid         
         GROUP BY s.dbid, s.instance_number, snap.begin_interval_time
        )
SELECT :v_pkey  || '|' ||  
       dbid  || '|' ||  
       instance_number  || '|' ||  
       begin_interval_time|| '|' ||  
       num_cpu_cores|| '|' || 
       os_load || '|' || 
       :v_dma_source_id || '|' || --dma_source_id  
       :v_manual_unique_id --dma_manual_id
FROM vossummary;

