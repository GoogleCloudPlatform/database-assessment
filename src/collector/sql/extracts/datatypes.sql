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
spool &outputdir/opdb__datatypes__&v_tag

WITH vdtype AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id con_id,
       owner,
       data_type,
       COUNT(1) as cnt,
       data_length, 
       data_precision, 
       data_scale, 
       avg_col_len,
       count(distinct &v_a_con_id||owner||table_name) as distinct_table_count
FROM   &v_tblprefix._tab_columns a
WHERE  owner NOT IN
                     (
                     SELECT name
                     FROM   SYSTEM.logstdby$skip_support
                     WHERE  action=0)
GROUP  BY '&&v_host'
          || '_'
          || '&&v_dbname'
          || '_'
          || '&&v_hora',
          &v_a_con_id ,
          owner,
          data_type,
          data_length,
          data_precision,
          data_scale,
          avg_col_len
)
SELECT pkey , con_id , owner , data_type , cnt,
       data_length, data_precision, data_scale, avg_col_len, distinct_table_count
FROM vdtype;
spool off
