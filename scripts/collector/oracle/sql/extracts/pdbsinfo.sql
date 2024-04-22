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
column logging format a10

spool &outputdir/opdb__pdbsinfo__&v_tag
prompt PKEY|DBID|PDB_ID|PDB_NAME|STATUS|LOGGING|CON_ID|CON_UID|EBS_OWNER|SIEBEL_OWNER|PSFT_OWNER|RDS_FLAG|OCI_AUTONOMOUS_FLAG|DBMS_CLOUD_PKG_INSTALLED|APEX_INSTALLED|SAP_OWNER|SGA_ALLOCATED_BYTES|PGA_USED_BYTES|PGA_ALLOCATED_BYTES|PGA_MAX_BYTES|DMA_SOURCE_ID|DMA_MANUAL_ID
WITH opdbinfo AS (
SELECT :v_pkey AS pkey,
       dbid,
       pdb_id,
       pdb_name,
       status,
       &v_pluggablelogging AS logging,
       con_id,
       con_uid
FROM   &v_tblprefix._pdbs
UNION
SELECT :v_pkey AS pkey,
       c.dbid, 
       c.con_id# AS pdb_id, 
       o.name, 
       decode(c.status, 0, 'UNUSABLE', 
                        1, 'NEW', 
                        2, 'NORMAL', 
                        3, 'UNPLUGGED',
                        5, 'RELOCATING',
                        6, 'REFRESHING',
                        7, 'RELOCATED',
                        8, 'STUB',
                           'UNDEFINED') AS status,
       decode(bitand(c.flags, 512), 512, 'NOLOGGING', 'LOGGING') AS logging,
       c.con_id# AS con_id,
       c.con_uid
FROM sys.container$ c, sys.obj$ o
WHERE o.obj# = c.obj# AND con_id#=1),
vpdbinfo AS (
            SELECT p.*,
@&EXTRACTSDIR/app_schemas.sql
            FROM opdbinfo p ),
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
SELECT i.*, m.sga_allocated_bytes, m.pga_used_bytes, m.pga_allocated_bytes, m.pga_max_bytes,
       :v_dma_source_id AS DMA_SOURCE_ID, :v_manual_unique_id AS DMA_MANUAL_ID
FROM  vpdbinfo i
      LEFT OUTER JOIN mem_stats m ON i.con_id = m.con_id;
spool off
column logging clear
