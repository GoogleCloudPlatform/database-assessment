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
define cdbjoin = "AND con_id = p.con_id"
spool &outputdir/opdb__pdbsinfo__&v_tag

WITH vpdbinfo AS (
SELECT '&&v_host'
       || '_'
       || '&&v_dbname'
       || '_'
       || '&&v_hora' AS pkey,
       dbid,
       pdb_id,
       pdb_name,
       status,
       logging,
       con_id,
       con_uid,
@&EXTRACTSDIR/app_schemas.sql
FROM   &v_tblprefix._pdbs p),
pdb_sga AS (
            SELECT con_id, inst_id, SUM(bytes) AS sga_allocated_bytes
            FROM  gv$sgastat
            GROUP BY con_id, inst_id
            ORDER BY  con_id, inst_id
           ),
pdb_pga AS (
            SELECT con_id, inst_id, SUM(pga_used_mem) AS pga_used_bytes , SUM(pga_alloc_mem) as pga_allocated_bytes, SUM(pga_max_mem) as pga_max_bytes
            FROM  gv$process
            GROUP BY con_id, inst_id
            ORDER BY  con_id, inst_id
           ),
mem_stats AS (
              SELECT s.con_id, s.inst_id, s.sga_allocated_bytes, p.pga_used_bytes, p.pga_allocated_bytes, p.pga_max_bytes
              FROM pdb_sga s 
              LEFT OUTER JOIN pdb_pga p 
                ON (s.con_id = p.con_id AND s.inst_id = p.inst_id)
             )
SELECT i.*, m.sga_allocated_bytes, m.pga_used_bytes, m.pga_allocated_bytes, m.pga_max_bytes
FROM  vpdbinfo i
      LEFT OUTER JOIN mem_stats m ON i.con_id = m.con_id;
spool off
