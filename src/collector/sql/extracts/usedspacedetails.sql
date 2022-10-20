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
spool &outputdir/opdb__usedspacedetails__&v_tag

WITH vused AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id,
       owner,
       segment_type,
       ROUND(SUM(bytes) / 1024 / 1024 / 1024, 0) GB
       FROM   &v_tblprefix._segments a
       WHERE  owner NOT IN (
                          SELECT name
                          FROM   SYSTEM.logstdby$skip_support
                          WHERE  action=0)
       GROUP  BY '&&v_host'
              || '_'
              || '&&v_dbname'
              || '_'
              || '&&v_hora',
              &v_a_con_id , owner, segment_type )
SELECT pkey , con_id , owner , segment_type , GB
FROM vused;
spool off
