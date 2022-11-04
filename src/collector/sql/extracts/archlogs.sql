/*
Copyright 2022 Google LLC

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    https://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/
spool &outputdir/opdb__archlogs__&v_tag

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       trunc(first_Time) as log_start_date, 
       to_char(first_time, 'HH24') as hour,
       thread# AS thread_num, 
       dest_id, 
       count(1) AS CNT, 
       round(sum(blocks * block_size)/1024/1024) as mbytes
FROM gv$archived_log
WHERE first_time >= trunc(sysdate) - '&&dtrange'
GROUP BY trunc(first_time), thread#, to_char(first_time, 'HH24'), dest_id
;
spool off
