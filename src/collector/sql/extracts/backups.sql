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
spool &outputdir/opdb__backups__&v_tag

SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       trunc(start_time) AS backup_start_date, 
       &v_a_con_id AS con_id, 
       input_type, 
       round(sum(elapsed_seconds)) AS elapsed_seconds, 
       round(sum(input_bytes)/1024/1024) AS mbytes_in, 
       round(sum(output_bytes)/1024/1024) AS mbytes_out
FROM v$rman_backup_job_details a
WHERE start_time >= trunc(sysdate) - '&&dtrange'
GROUP BY trunc(start_time), input_type, &v_a_con_id
;
spool off
