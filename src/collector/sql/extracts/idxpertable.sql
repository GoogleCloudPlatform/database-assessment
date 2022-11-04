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
spool &outputdir/opdb__idxpertable__&v_tag

WITH vrawidx AS(
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id, table_owner, table_name, count(1) idx_cnt
FROM &v_tblprefix._indexes a
WHERE  owner NOT IN
                    ( SELECT name
                      FROM   SYSTEM.logstdby$skip_support
                      WHERE  action=0)
group by &v_a_con_id, table_owner, table_name),
vcidx AS (
SELECT pkey,
       con_id,
       count(table_name) tab_count,
       idx_cnt,
       round(100*ratio_to_report(count(table_name)) over ()) idx_perc
FROM vrawidx
GROUP BY pkey, con_id, idx_cnt)
SELECT pkey , con_id , tab_count , idx_cnt , idx_perc
FROM vcidx;
spool off
