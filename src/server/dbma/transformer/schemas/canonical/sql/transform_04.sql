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
--name: transform-04!
--This query will evaluate the customer's on-premises environment and right-size the workload on BMS using the same on-premises server to database mapping On-premises host details
create or replace table T_DS_BMS_sizing as WITH hostdetails AS (
        SELECT TRIM(dbinstances.pkey) AS PKEY,
            dbinstances.host_name as host_name,
            (metrics.INSTANCE_NUMBER) AS instanceNumber,
            MAX(
                CAST(
                    metrics.NUM_CPU_CORES_CUMULATIVE_VALUE AS DECIMAL
                )
            ) AS cores,
            MAX(
                CAST(
                    metrics.PHYSICAL_MEMORY_BYTES_CUMULATIVE_VALUE AS DECIMAL
                ) / 1024 / 1024 / 1024
            ) AS totalMemoryGB
        FROM awrhistosstat_rs AS metrics
            INNER JOIN dbinstances AS dbinstances ON TRIM(metrics.PKEY) = TRIM(dbinstances.pkey)
            AND (metrics.INSTANCE_NUMBER) = (dbinstances.inst_id)
        GROUP BY dbinstances.pkey,
            dbinstances.host_name,
            instanceNumber
    ),
    DB_number AS --Identify the number of databases per servers
    (
        select dbinstances.host_name,
            count (instance_name) as Database_count
        FROM dbinstances as dbinstances
        group by dbinstances.host_name
    ),
    --Database CPU Usage
    --Description - Sum the DB CPUs for each host server by hour then find the peak hour
    DBCPU AS (
        SELECT *
        FROM T_DS_CPU_CALC
    ),
    --Database Storage Used
    --Description: Find the total database storage needed per host.  For RAC databases count the storage once per RAC cluster
    --Only datafiles size is used to determine storage size with no storage uplift
    DBStorage AS (
        select DISTINCT dbsizing_facts.PKEY,
            dbinstances.host_name,
            dbsizing_facts.INSTANCE_NUMBER,
            --dbsizing_facts.DB_SIZE_ALLOCATED_GB,
            CAST(dbsizing_facts.DB_SIZE_ALLOCATED_GB as numeric) / 1024 as DB_SIZE_ALLOCATED_GB
        from dbsizing_facts AS dbsizing_facts
            inner join dbinstances as dbinstances on trim(dbsizing_facts.pkey) = trim(dbinstances.pkey)
            and (dbsizing_facts.INSTANCE_NUMBER) = (dbinstances.inst_id)
            and (dbsizing_facts.HOUR) = 0
        order by dbsizing_facts.PKEY,
            dbsizing_facts.INSTANCE_NUMBER
    ),
    StorageRanking AS --Rank the data in order to only count the storage once per RAC cluster
    (
        SELECT host_name,
            INSTANCE_NUMBER,
            CAST(DB_SIZE_ALLOCATED_GB AS NUMERIC) AS DB_SIZE_ALLOCATED_GB,
            RANK() OVER (
                PARTITION BY PKEY
                ORDER BY PKEY,
                    INSTANCE_NUMBER
            ) AS Ranking
        FROM DBstorage
    ),
    StorageSizeSums AS --Select the first storage value
    (
        SELECT *
        FROM StorageRanking
        WHERE Ranking = 1
    ),
    StorageMissing AS --Identify storage entries that will not be used in the calculation
    (
        SELECT host_name
        FROM StorageRanking
        EXCEPT DISTINCT
        SELECT host_name
        FROM StorageSizeSums
    ),
    StorageFinalResults AS --Display the storage results counting the storage once per RAC cluster
    (
        SELECT host_name,
            CEIL(SUM(DB_SIZE_ALLOCATED_GB)) AS DB_size_TB
        FROM StorageSizeSums
        GROUP BY host_name
        UNION ALL
        SELECT host_name,
            0
        FROM StorageMissing
        ORDER BY host_name
    ),
    --Database Memory Usage
    DBMEMORY as(
        Select --sum the database memory for each host
            a.host_name,
            round((sum(a.SGA_SIZE_GB) * 1.10)) as SGA_SIZE_GB --memory is uplifted 10% to account for growth
        from (
                SELECT --select the database memory required
                    dbparameters.PKEY,
                    dbparameters.inst_id,
                    hostdetails.host_name,
                    CAST(dbparameters.value as numeric) / 1024 / 1024 / 1024 as SGA_SIZE_GB
                FROM dbparameters as dbparameters
                    INNER JOIN hostdetails as hostdetails ON TRIM(hostdetails.PKEY) = TRIM(dbparameters.PKEY)
                    and CAST(hostdetails.instanceNumber as numeric) = CAST(dbparameters.INST_ID as numeric)
                    and TRIM(dbparameters.name) = 'sga_target'
            ) a
        group by 1
    ),
    --Database Storage IO Requirements
    --Description: Determine the storage performance requirements by selecting IOPS and MBp/s (throughput), then uplift the storage size to meet the storage performance requirements
    DBIO as(
        select --Step 2 - Find the max IOPS and MBps across the 24 hours at the 95% percentile
            pkey,
            max(a.iombps_total_perc95) as iombps_total_perc95,
            max(a.iops_total_perc95) as iops_total_perc95
        FROM (
                SELECT -- Step 1 -find the SUM of IOPS and MBps by database for each hour
                    sysstat.pkey,
                    dbid,
                    hour,
                    ROUND(
                        (
                            SUM(physical_read_total_bytes_perc95) + SUM(physical_write_total_bytes_perc95)
                        ) / 1024 / 1024,
                        2
                    ) iombps_total_perc95,
                    SUM(physical_read_total_io_requests_perc95) + SUM(physical_write_total_io_req_perc95) iops_total_perc95
                FROM vsysstat_columnar as sysstat --  JOIN vdbinstances as dbinstance
                    --  ON sysstat.PKEY = dbinstance.PKEY AND sysstat.instance_number = dbinstance.inst_id
                GROUP BY sysstat.pkey,
                    dbid,
                    hour
                order by pkey
            ) a
        group by 1
    ),
    DBHostName as(
        select --Determine the host_names of the on-premises servers
            DISTINCT sysstat.pkey,
            host_name
        from vsysstat_columnar as sysstat -- WAP Does not need to be this view?
            JOIN dbinstances as dbinstance ON sysstat.PKEY = dbinstance.PKEY
            AND sysstat.instance_number = dbinstance.inst_id
    ),
    DBHostJoin as(
        select --Join the on-premises hosts to the databases
            DBIO.*,
            MIN(DBhostName.host_name) as host_name
        from DBIO
            inner join DBhostName using (PKEY)
        group by 1,
            2,
            3
    ),
    DBIOMissing AS (
        SELECT --Find which on-premises hosts are part of a RAC database
            DISTINCT host_name
        FROM DBHostName
        EXCEPT DISTINCT
        SELECT DISTINCT host_name
        FROM DBHostJoin
    ),
    DBIOFinalResults AS (
        SELECT --Sum the results of the RAC databases for each host
            host_name,
            sum(DBHostjoin.iombps_total_perc95) as iombps_total_perc95,
            sum(DBHostjoin.iops_total_perc95) as iops_total_perc95
        FROM DBHostJoin
        group by 1
        UNION ALL
        SELECT host_name,
            0,
            0
        FROM DBIOMissing
        ORDER BY host_name
    ),
    --Calculate Storage size based on on-premises performance requirements
    --Description: Determine the required SSD and HT storage size required based on IOPS and MBp/s
    --For SSD, QoS of 56 MBp/s and 7200 IOPS per TB was used (defined by BMS PM team)
    --For HT, QoS of 900 MBp/s and 28800 per 4 TB was used
    DBIO_sizing as(
        Select DBCPU.host_name,
            StorageFinalResults.DB_size_TB,
            COALESCE(
                CASE
                    when DBIOFinalResults.iops_total_perc95 = 0
                    or DBIOFinalResults.iombps_total_perc95 = 0 then 0
                    when DBIOFinalResults.iops_total_perc95 < 7200
                    and DBIOFinalResults.iombps_total_perc95 < 56 then CEIL(StorageFinalResults.DB_size_TB)
                    when DBIOFinalResults.iops_total_perc95 / 7200 > DBIOFinalResults.iombps_total_perc95 / 56 then CEIL(DBIOFinalResults.iops_total_perc95 / 7200)
                    else CEIL(DBIOFinalResults.iombps_total_perc95 / 56)
                end,
                0
            ) as SSD_Storage_TB,
            --calcualte the SSD storage required
            CASE
                when DBIOFinalResults.iops_total_perc95 = 0
                or DBIOFinalResults.iombps_total_perc95 = 0 then 0
                when DBIOFinalResults.iops_total_perc95 < 28800
                and DBIOFinalResults.iombps_total_perc95 < 900
                AND CEIL(StorageFinalResults.DB_size_TB) < 16 then 1
                when DBIOFinalResults.iops_total_perc95 < 28800
                and DBIOFinalResults.iombps_total_perc95 < 900
                AND CEIL(StorageFinalResults.DB_size_TB) > 16 then 1 + round((StorageFinalResults.DB_size_TB) / 16)
                when CEIL(DBIOFinalResults.iops_total_perc95 / 28800) > CEIL(DBIOFinalResults.iombps_total_perc95 / 900)
                AND CEIL(StorageFinalResults.DB_size_TB) < 16 then CEIL(DBIOFinalResults.iops_total_perc95 / 28800)
                when CEIL(DBIOFinalResults.iops_total_perc95 / 28800) < CEIL(DBIOFinalResults.iombps_total_perc95 / 900)
                AND CEIL(StorageFinalResults.DB_size_TB) < 16 then CEIL(DBIOFinalResults.iombps_total_perc95 / 900)
                when CEIL(DBIOFinalResults.iops_total_perc95 / 28800) > CEIL(DBIOFinalResults.iombps_total_perc95 / 900)
                AND CEIL(StorageFinalResults.DB_size_TB) > 16 then CEIL(DBIOFinalResults.iops_total_perc95 / 28800)
                when CEIL(DBIOFinalResults.iops_total_perc95 / 28800) < CEIL(DBIOFinalResults.iombps_total_perc95 / 900)
                AND CEIL(StorageFinalResults.DB_size_TB) > 16 then (
                    CASE
                        when round((StorageFinalResults.DB_size_TB) / 16) < CEIL(DBIOFinalResults.iombps_total_perc95 / 900) then CEIL(DBIOFinalResults.iombps_total_perc95 / 900)
                        when round((StorageFinalResults.DB_size_TB) / 16) > CEIL(DBIOFinalResults.iombps_total_perc95 / 900) then CEIL(DBIOFinalResults.iombps_total_perc95 / 900) + round((StorageFinalResults.DB_size_TB) / 16)
                    end
                )
                else 0
            end as High_Throughput_per_4TB --calculate the HT storage required
        from DBIOFinalResults as DBIOFinalResults
            inner join DBCPU using (host_name)
            inner join StorageFinalResults using (host_name)
    ),
    --Calculate the BMS Pricing
    DBPRICING as (
        SELECT a.*,
            machinesizes.EST_PRICE as BMS_Server_Price,
            machinesizes.CORES as BMS_cores_count,
            machinesizes.RAM_GB as BMS_memory
        FROM (
                SELECT DBMEMORY.host_name,
                    DB_number.Database_count,
                    DBMEMORY.SGA_SIZE_GB,
                    DBCPU.DB_CPU_CORES,
                    DBCPU.Server_Cores,
                    CEIL(StorageFinalResults.DB_size_TB) as DB_size_TB,
                    COALESCE(DBIOFinalResults.iombps_total_perc95, 0) iombps_total_perc95,
                    COALESCE(
                        DBIOFinalResults.iops_total_perc95,
                        CAST(0 as NUMERIC)
                    ) iops_total_perc95,
                    CASE
                        --DB CPU is sized at the 75% capacity of the BMS server.
                        WHEN DBCPU.DB_CPU_CORES < 8 *.75
                        AND DBMEMORY.SGA_SIZE_GB < 192 THEN 'XS'
                        WHEN DBCPU.DB_CPU_CORES < 8 *.75
                        AND DBMEMORY.SGA_SIZE_GB >= 192
                        and DBMEMORY.SGA_SIZE_GB < 384 Then 'S'
                        WHEN DBCPU.DB_CPU_CORES < 8 *.75
                        AND DBMEMORY.SGA_SIZE_GB >= 384
                        and DBMEMORY.SGA_SIZE_GB < 768 Then 'M'
                        WHEN DBCPU.DB_CPU_CORES < 8 *.75
                        AND DBMEMORY.SGA_SIZE_GB >= 768
                        and DBMEMORY.SGA_SIZE_GB < 1536 Then 'L'
                        WHEN DBCPU.DB_CPU_CORES < 8 *.75
                        AND DBMEMORY.SGA_SIZE_GB >= 1536
                        and DBMEMORY.SGA_SIZE_GB < 3072 Then 'XL'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 8 *.75
                            AND DBCPU.DB_CPU_CORES < 16 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB < 384 THEN 'S'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 8 *.75
                            AND DBCPU.DB_CPU_CORES < 16 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB >= 384
                        and DBMEMORY.SGA_SIZE_GB < 768 THEN 'M'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 8 *.75
                            AND DBCPU.DB_CPU_CORES < 16 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB >= 768
                        and DBMEMORY.SGA_SIZE_GB < 1536 THEN 'L'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 8 *.75
                            AND DBCPU.DB_CPU_CORES < 16 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB >= 1536
                        and DBMEMORY.SGA_SIZE_GB < 3072 THEN 'XL'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 16 *.75
                            AND DBCPU.DB_CPU_CORES < 24 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB < 768 THEN 'M'
                        WHEN (
                            (
                                DBCPU.DB_CPU_CORES >= 16 *.75
                                AND DBCPU.DB_CPU_CORES < 24 *.75
                            )
                            AND (
                                DBMEMORY.SGA_SIZE_GB >= 768
                                AND DBMEMORY.SGA_SIZE_GB < 1536
                            )
                        ) THEN 'L'
                        WHEN (
                            (
                                DBCPU.DB_CPU_CORES >= 16 *.75
                                AND DBCPU.DB_CPU_CORES < 24 *.75
                            )
                            AND (
                                DBMEMORY.SGA_SIZE_GB >= 1536
                                AND DBMEMORY.SGA_SIZE_GB < 3072
                            )
                        ) THEN 'XL'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 24 *.75
                            AND DBCPU.DB_CPU_CORES < 56 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB < 1536 THEN 'L'
                        WHEN (
                            (
                                DBCPU.DB_CPU_CORES >= 24 *.75
                                AND DBCPU.DB_CPU_CORES < 56 *.75
                            )
                            AND (
                                DBMEMORY.SGA_SIZE_GB >= 1536
                                AND DBMEMORY.SGA_SIZE_GB < 3072
                            )
                        ) THEN 'XL'
                        WHEN (
                            DBCPU.DB_CPU_CORES >= 56 *.75
                            AND DBCPU.DB_CPU_CORES < 112 *.75
                        )
                        AND DBMEMORY.SGA_SIZE_GB < 3072 THEN 'XL'
                        ELSE 'No Match, please consolidate or distribute '
                    END AS BMS_Server_Size,
                    DBIO_sizing.SSD_Storage_TB,
                    DBIO_SIZING.SSD_Storage_TB * 115 as SSD_Storage_Price,
                    DBIO_SIZING.High_Throughput_per_4TB,
                    CASE
                        When DBIO_SIZING.High_Throughput_per_4TB = 0 then 0
                        When DBIO_SIZING.High_Throughput_per_4TB = CEIL(StorageFinalResults.DB_size_TB)
                        AND DBIO_SIZING.High_Throughput_per_4TB <= 4 Then 828
                        When DBIO_SIZING.High_Throughput_per_4TB * 4 >= CEIL(StorageFinalResults.DB_size_TB) Then DBIO_SIZING.High_Throughput_per_4TB * 828
                        When DBIO_SIZING.High_Throughput_per_4TB * 4 <= CEIL(StorageFinalResults.DB_size_TB) Then (
                            (
                                CEIL(StorageFinalResults.DB_size_TB) - (DBIO_SIZING.High_Throughput_per_4TB * 4)
                            ) * 84
                        ) + (828 * DBIO_SIZING.High_Throughput_per_4TB)
                        ELSE 0
                    end as High_Throughput_Pricing
                from DBMEMORY
                    LEFT join DBIOFinalResults USING (host_name)
                    LEFT JOIN DBIO_SIZING USING (host_name)
                    LEFT JOIN DB_number using (host_name)
                    LEFT JOIN StorageFinalResults using (host_name)
                    LEFT JOIN DBCPU USING (host_name)
                order by host_name
            ) a
            LEFT JOIN optimusconfig_bms_machinesizes AS machinesizes ON machinesizes.MACHINE_SIZE_SHORT = BMS_Server_Size
    ),
    --Calculate the Final BMS Pricing based on the preferred storage option
    FinalTable as (
        select DBPRICING.*,
            CASE
                when High_Throughput_Pricing * 1.1 >= SSD_Storage_Price then 'SSD' --Added 10% price guardrail as per Michelle (BMS PM)
                when High_Throughput_Pricing * 1.1 < SSD_Storage_Price then 'HT' --Added 10% price guardrail as per Michelle (BMS PM)
            end as Perferred_storage,
            CASE
                when High_Throughput_Pricing = 0 then cast(BMS_Server_Price as numeric)
                when High_Throughput_Pricing * 1.1 > SSD_Storage_Price then cast(BMS_Server_Price as numeric) + cast(SSD_Storage_Price as numeric) --Added 10% price guardrail as per Michelle (BMS PM)
                when High_Throughput_Pricing * 1.1 < SSD_Storage_Price then cast(BMS_Server_Price as numeric) + cast(High_Throughput_Pricing as numeric) --Added 10% price guardrail as per Michelle (BMS PM)
            end as Total_BMS_Price_using_HT_Storage,
            cast(SSD_Storage_Price as numeric) + cast(BMS_Server_Price as numeric) Total_BMS_Price_using_SSD_Storage
        from DBPRICING
    )
select *,
    CASE
        when Finaltable.DB_size_TB > (CEIL(High_Throughput_per_4TB * 4))
        AND Perferred_storage = 'HT' then CEIL(
            finalTable.DB_size_TB - (High_Throughput_per_4TB * 4)
        )
        else 0
    end as High_Throughput_Additional_TB
from FinalTable
order by 1;