/* 
 # Copyright 2022 Google LLC
 #
 # Licensed under the Apache License, Version 2.0 (the "License");
 # you may not use this file except in compliance with the License.
 # You may obtain a copy of the License at
 #
 #     https://www.apache.org/licenses/LICENSE-2.0
 #
 # Unless required by applicable law or agreed to in writing, software
 # distributed under the License is distributed on an "AS IS" BASIS,
 # WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 # See the License for the specific language governing permissions and
 # limitations under the License.
 */
--name: transform-08!
Create or replace view V_DS_HostDetails as WITH hostdetails AS (
        SELECT b.pkey,
            b.host_name,
            a.INSTANCE_NUMBER AS instanceNumber,
            MAX(
                CAST(a.NUM_CPU_CORES_CUMULATIVE_VALUE AS DECIMAL)
            ) AS cores,
            MAX(
                CAST(
                    a.PHYSICAL_MEMORY_BYTES_CUMULATIVE_VALUE AS DECIMAL
                )
            ) AS totalMemory,
            MAX(CAST(a.HOST_CPU_UTILIZATION AS DECIMAL)) AS maxHOSTCPUUtilizationPercentage,
            AVG(CAST(a.HOST_CPU_UTILIZATION AS DECIMAL)) AS avgHOSTCPUUtilizationPercentage
        FROM awrhistosstat_rs a,
            dbinstances b
        WHERE TRIM(a.PKEY) = TRIM(b.pkey)
            AND a.INSTANCE_NUMBER = b.inst_id
        GROUP BY b.pkey,
            b.host_name,
            instanceNumber
    ),
    db_details AS (
        SELECT DISTINCT a.pkey,
            a.db_name,
            a.cdb AS iscdb,
            a.redo_gb_per_day,
            a.rac_dbinstaces,
            a.platform_name,
            a.db_size_allocated_gb,
            a.db_size_in_use_gb,
            a.dg_database_role,
            a.dg_protection_level
        FROM dbsummary a
    ),
    sourceSizing AS (
        SELECT a.PKEY,
            a.db_name,
            b.host_name,
            b.instanceNumber,
            a.iscdb,
            a.redo_gb_per_day,
            CASE
                WHEN a.rac_dbinstaces > 1 THEN TRUE
                ELSE FALSE
            END AS isRacDB,
            a.platform_name,
            (a.db_size_allocated_gb) AS db_size_allocated_gb,
            (a.db_size_in_use_gb) AS db_size_in_use_gb,
            SUM(b.cores) AS cores,
            SUM(b.totalMemory) AS totalMemory,
            MAX(b.maxHOSTCPUUtilizationPercentage) AS maxHostCPUUtilizationPercentage,
            AVG(b.avgHOSTCPUUtilizationPercentage) AS avgHostCPUUtilizationPercentage
        FROM db_details a,
            hostdetails b
        WHERE TRIM(a.PKEY) = TRIM(b.pkey)
        GROUP BY 1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            9,
            10
    )
select *
from sourceSizing
order by host_name;