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
exec dbms_application_info.set_action('pdbsinfo');
WITH opdbinfo AS (
    SELECT :v_pkey AS pkey,
           dbid,
           pdb_id,
           pdb_name,
           status,
           &s_pluggablelogging. AS logging,
           con_id,
           con_uid
    FROM   &s_tblprefix._pdbs
    UNION
    SELECT :v_pkey AS pkey,
           c.dbid,
           c.con_id# AS pdb_id,
           o.name,
           DECODE(c.status, 0, 'UNUSABLE',
                            1, 'NEW',
                            2, 'NORMAL',
                            3, 'UNPLUGGED',
                            5, 'RELOCATING',
                            6, 'REFRESHING',
                            7, 'RELOCATED',
                            8, 'STUB',
                               'UNDEFINED') AS status,
           DECODE(BITAND(c.flags, 512), 512, 'NOLOGGING', 'LOGGING') AS logging,
           c.con_id# AS con_id,
           c.con_uid
    FROM sys.container$ c, 
         sys.obj$ o
    WHERE o.obj# = c.obj# AND con_id#=1
),
vpdbinfo AS (
            SELECT pkey, 
                   dbid, 
                   pdb_id, 
                   pdb_name, 
                   status, 
                   logging, 
                   con_id, 
                   con_uid, 
@sql/extracts/app_schemas_pdbsinfo.sql 
            FROM opdbinfo p ),
pdb_sga AS (
            SELECT con_id, 
                   inst_id, 
                   SUM(bytes) AS sga_allocated_bytes
            FROM  gv$sgastat
            GROUP BY con_id, inst_id
            ORDER BY con_id, inst_id
           ),
pdb_pga AS (
            SELECT con_id, 
                   inst_id, 
                   SUM(pga_used_mem) AS pga_used_bytes , 
                   SUM(pga_alloc_mem) AS pga_allocated_bytes, 
                   SUM(pga_max_mem) AS pga_max_bytes
            FROM  gv$process
            GROUP BY con_id, inst_id
            ORDER BY con_id, inst_id
           ),
mem_stats AS (
              SELECT s.con_id, 
                     s.inst_id, 
                     s.sga_allocated_bytes, 
                     p.pga_used_bytes, 
                     p.pga_allocated_bytes, 
                     p.pga_max_bytes
              FROM pdb_sga s
              LEFT OUTER JOIN pdb_pga p
                           ON (s.con_id = p.con_id AND s.inst_id = p.inst_id)
             ),
vpdbmode as (
             SELECT con_id, 
                    open_mode, 
                    total_size / 1024 / 1024 / 1024 AS total_gb
             FROM   v$pdbs 
            )
SELECT i.pkey, 
       i.dbid, 
       i.pdb_id, 
       i.pdb_name, 
       i.status, 
       i.logging, 
       i.con_id, 
       i.con_uid,
       i.ebs_owner, 
       i.siebel_owner, 
       i.psft_owner, 
       i.rds_flag, 
       i.oci_autonomous_flag, 
       i.dbms_cloud_pkg_installed, 
       i.apex_installed, 
       i.sap_owner,
       m.sga_allocated_bytes, 
       m.pga_used_bytes, 
       m.pga_allocated_bytes, 
       m.pga_max_bytes, 
       p.open_mode, 
       p.total_gb,
       :v_dma_source_id AS dma_source_id, 
       :v_manual_unique_id AS dma_manual_id
FROM  vpdbinfo i
      LEFT OUTER JOIN mem_stats m ON i.con_id = m.con_id
      LEFT OUTER JOIN vpdbmode p ON i.con_id = p.con_id;

