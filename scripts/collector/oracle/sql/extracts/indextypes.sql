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
COLUMN PARTITIONED FORMAT A20
COLUMN TEMPORARY FORMAT A20
COLUMN SECONDARY FORMAT A20
COLUMN UNIQUENESS FORMAT A20
COLUMN JOIN_INDEX FORMAT A20
COLUMN CUSTOM_INDEX_TYPE FORMAT A20
spool &outputdir/opdb__indextypes__&v_tag

WITH vidxtype AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       &v_a_con_id AS con_id,
       a.owner,
       a.index_type,
       a.uniqueness,
       a.compression,
       a.partitioned,
       a.temporary,
       a.secondary,
       a.visibility,                      
       a.join_index,
       CASE WHEN a.ityp_owner IS NOT NULL THEN 'Y' ELSE 'N' END AS custom_index_type,
       COUNT(1) as cnt
FROM   &v_tblprefix._indexes a
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
          a.owner,
          a.index_type,
          a.uniqueness,
          a.compression,
          a.partitioned,
          a.temporary,
          a.secondary,
          a.visibility,                      
          a.join_index,
          CASE WHEN a.ityp_owner IS NOT NULL THEN 'Y' ELSE 'N' END
) 
SELECT pkey , 
       con_id , 
       owner , 
       index_type , 
       uniqueness,
       compression,
       partitioned,
       temporary,
       secondary,
       visibility,                      
       join_index,
       custom_index_type,
       cnt
FROM vidxtype;
spool off
COLUMN PARTITIONED CLEAR
COLUMN TEMPORARY CLEAR
COLUMN SECONDARY CLEAR
COLUMN UNIQUENESS CLEAR
COLUMN JOIN_INDEX CLEAR
COLUMN CUSTOM_INDEX_TYPE CLEAR
