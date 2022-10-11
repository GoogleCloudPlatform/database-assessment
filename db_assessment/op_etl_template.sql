--------------------------------------------------------------------------------------
--This script creates the BQ views required for the Data Studio Template
--To execute this script you will need to alter the script to run in your project
--Use the find/replace to replace the following value:
--“projectID.dataset” = your_project_name.your_data_set
--Project - Optimus Prime 
--Date - 30-June-2022
--Version 2.0.1
--------------------------------------------------------------------------------------
--Name: P_DS_CPU_CALC
--Description: Manually calculate the CPU used by the database. This procedure will create the table T_DS_CPU_CALC
Create or replace procedure `projectID.dataset.P_DS_CPU_CALC` ()
Begin
create or replace table `projectID.dataset.T_DS_CPU_CALC` as
WITH hostdetails AS (
SELECT
   TRIM(dbinstances.pkey) AS PKEY,
    dbinstances.host_name as host_name,
    CAST(metrics._INSTANCE_NUMBER AS INT64) AS instanceNumber,
    MAX(CAST(metrics.NUM_CPU_CORES_CUMULATIVE_VALUE AS DECIMAL)) AS cores,
    MAX(CAST(metrics.PHYSICAL_MEMORY_BYTES_CUMULATIVE_VALUE AS DECIMAL)/1024/1024/1024) AS totalMemoryGB,
FROM `projectID.dataset.awrhistosstat_rs_metrics` AS metrics
    INNER JOIN `projectID.dataset.dbinstances` AS dbinstances
            ON TRIM(metrics._PKEY) = TRIM(dbinstances.pkey)                                
           AND CAST(metrics._INSTANCE_NUMBER AS INT64) = CAST(dbinstances.inst_id AS INT64)
GROUP BY dbinstances.pkey,
        dbinstances.host_name,
        instanceNumber
          
),
vcputimemodel as (
SELECT pkey, dbid, instance_number, hour,
    AVG(DB_CPU_PERC95) DB_CPU_PERC95,
    AVG(BACKG_CPU_TIME_PERC95) BACKG_CPU_TIME_PERC95,
    AVG(DB_TIME_PERC95) DB_TIME_PERC95,
    AVG(SQL_EXEC_ELAPS_TIME_PERC95) SQL_EXEC_ELAPS_TIME_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
PERCENTILE_CONT(DB_CPU_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS DB_CPU_PERC95,
PERCENTILE_CONT(BACKG_CPU_TIME_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS BACKG_CPU_TIME_PERC95,
PERCENTILE_CONT(DB_TIME_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS DB_TIME_PERC95,
PERCENTILE_CONT(SQL_EXEC_ELAPS_TIME_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS SQL_EXEC_ELAPS_TIME_PERC95,
FROM
 (
     SELECT pkey, dbid, instance_number, hour,
         CASE
           WHEN trim(a.stat_name) = 'DB CPU' then cast(perc95_value as numeric)
         END DB_CPU_PERC95,
         CASE
           WHEN trim(a.stat_name) = 'background cpu time' then cast(perc95_value as numeric)
         END BACKG_CPU_TIME_PERC95,
         CASE
           WHEN trim(a.stat_name) = 'DB time' then cast(perc95_value as numeric)
         END DB_TIME_PERC95,
         CASE
           WHEN trim(a.stat_name) = 'sql execute elapsed time' then cast(perc95_value as numeric)
         END SQL_EXEC_ELAPS_TIME_PERC95
     FROM `projectID.dataset.vdbahistsystimemodel` a
     WHERE TRIM(a.stat_name) IN ( 'DB CPU', 'background cpu time', 'DB time', 'sql execute elapsed time')
 ))
GROUP BY pkey, dbid, instance_number, hour
),
vcpusysstat AS (
SELECT pkey, dbid, instance_number, hour,
    AVG(RECURSIVE_CPU_PERC95) RECURSIVE_CPU_PERC95,
    AVG(PARSE_CPU_PERC95) PARSE_CPU_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
PERCENTILE_CONT(RECURSIVE_CPU_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS RECURSIVE_CPU_PERC95,
PERCENTILE_CONT(PARSE_CPU_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS PARSE_CPU_PERC95,
FROM(
SELECT pkey, dbid, instance_number, hour,
        CASE
          WHEN trim(a.stat_name) = 'recursive cpu usage' then cast(perc95_value as numeric)
        END RECURSIVE_CPU_PERC95,
        CASE
          WHEN trim(a.stat_name) = 'parse time cpu' then cast(perc95_value as numeric)
        END PARSE_CPU_PERC95
FROM `projectID.dataset.vdbahistsysstat` a
WHERE TRIM(a.stat_name) IN ('recursive cpu usage', 'parse time cpu')))
GROUP BY pkey, dbid, instance_number, hour
),
vcpuosstat AS (
SELECT pkey, dbid, instance_number, hour,
    AVG(NUM_CPU_CORES_PERC95) NUM_CPU_CORES_PERC95,
    AVG(NUM_CPUS_PERC95) NUM_CPUS_PERC95,
    AVG(BUSY_TIME_PERC95) BUSY_TIME_PERC95,
    AVG(IDLE_TIME_PERC95) IDLE_TIME_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
PERCENTILE_CONT(NUM_CPU_CORES, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS NUM_CPU_CORES_PERC95,
PERCENTILE_CONT(NUM_CPUS, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS NUM_CPUS_PERC95,
PERCENTILE_CONT(BUSY_TIME, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS BUSY_TIME_PERC95,
PERCENTILE_CONT(IDLE_TIME, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS IDLE_TIME_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
        CASE
          WHEN trim(a.stat_name) = 'NUM_CPU_CORES' then cast(CUMULATIVE_VALUE as numeric)
        END NUM_CPU_CORES,
        CASE
          WHEN trim(a.stat_name) = 'NUM_CPUS' then cast(CUMULATIVE_VALUE as numeric)
        END NUM_CPUS,
        CASE
          WHEN trim(a.stat_name) = 'BUSY_TIME' then cast(perc95 as numeric)
        END BUSY_TIME,
        CASE
          WHEN trim(a.stat_name) = 'IDLE_TIME' then cast(perc95 as numeric)
        END IDLE_TIME,
FROM `projectID.dataset.awrhistosstat` a
WHERE TRIM(a.stat_name) IN ('NUM_CPU_CORES', 'NUM_CPUS', 'BUSY_TIME', 'IDLE_TIME')))
GROUP BY pkey, dbid, instance_number, hour
),
vhandlingzeroCPU AS (
SELECT tm.pkey, tm.dbid, tm.instance_number, tm.hour,
    ROUND((DB_CPU_PERC95/1000000),2) DB_CPU_P95_SECONDS,
    ROUND((BACKG_CPU_TIME_PERC95/1000000),2) BACKG_CPU_TIME_P95_SECONDS,
    ROUND((RECURSIVE_CPU_PERC95/100),2) RECURSIVE_CPU_P95_SECONDS,
    ROUND((PARSE_CPU_PERC95/100),2) PARSE_CPU_P95_SECONDS,
    ROUND(cast(BUSY_TIME_PERC95 as numeric)/100,2) OS_BUSY_TIME_P95_SECONDS,
    ROUND(cast(IDLE_TIME_PERC95 as numeric)/100,2) OS_IDLE_TIME_P95_SECONDS,
    ROUND(((DB_CPU_PERC95/1000000 + BACKG_CPU_TIME_PERC95/1000000)*100)/ (cast(BUSY_TIME_PERC95 as numeric)/100 + cast(IDLE_TIME_PERC95 as numeric)/100),2) DB_CPU_USAGE_PERCENTAGE,
    ROUND(((cast(BUSY_TIME_PERC95 as numeric)/100)*100)/(cast(BUSY_TIME_PERC95 as numeric)/100 + cast(IDLE_TIME_PERC95 as numeric)/100),2) HOST_CPU_USAGE_PERCENTAGE,
    NUM_CPU_CORES_PERC95,
    NUM_CPUS_PERC95,
    ROUND((cast(BUSY_TIME_PERC95 as numeric)/100 + cast(IDLE_TIME_PERC95 as numeric)/100)/cast(avg_snaps_diff_secs AS NUMERIC)) NUM_CPU_CORES_CALC_RVENG,
FROM vcputimemodel tm
INNER JOIN  vcpusysstat st
ON tm.pkey = st.pkey
AND tm.dbid = st.dbid
AND tm.instance_number = st.instance_number
AND tm.hour = st.hour
INNER JOIN  vcpuosstat os
ON trim(tm.pkey) = trim(os.pkey)
AND CAST(tm.dbid AS NUMERIC) = CAST(os.dbid AS NUMERIC)
AND CAST(tm.instance_number AS NUMERIC) = CAST(os.instance_number AS NUMERIC)
AND CAST(tm.hour AS NUMERIC) = CAST(os.hour AS NUMERIC)
INNER JOIN `projectID.dataset.awrsnapdetails` snp
ON tm.pkey = snp.pkey
AND tm.dbid = CAST(snp.dbid AS numeric)
AND tm.instance_number = CAST(snp.instance_number AS numeric)
AND tm.hour = CAST(snp.hour AS numeric)
ORDER BY tm.pkey, tm.dbid, tm.instance_number, tm.hour
),
DBCPU AS (
SELECT
b.host_name,
round(max((b.DB_CPU_CORES)*1.1)+1,2) as DB_CPU_CORES, --uplifted the DB CPU 10% to account for growth and added one additional core for the OS
ROUND(max(b.NUM_CPU_CORES_PERC95),0) as Server_Cores
FROM
(
Select
a.host_name,a.hour,
sum(a.DB_CPU_CORES) as DB_CPU_CORES, --sum the DB cores per instance on each host
max(a.NUM_CPU_CORES_PERC95) as NUM_CPU_CORES_PERC95
From
(
SELECT cpu.pkey, cpu.dbid, cpu.instance_number, cpu.hour,
    host.host_name,
    DB_CPU_USAGE_PERCENTAGE,
    HOST_CPU_USAGE_PERCENTAGE,
    ROUND(DB_CPU_USAGE_PERCENTAGE * (IF (NUM_CPU_CORES_PERC95 = 0, NUM_CPU_CORES_CALC_RVENG, NUM_CPU_CORES_PERC95))/100,2) DB_CPU_CORES,
    CEIL(HOST_CPU_USAGE_PERCENTAGE * (IF (NUM_CPU_CORES_PERC95 = 0, NUM_CPU_CORES_CALC_RVENG, NUM_CPU_CORES_PERC95))/100) HOST_CORES,
    NUM_CPU_CORES_PERC95,
    NUM_CPUS_PERC95,
    NUM_CPU_CORES_CALC_RVENG,
FROM vhandlingzeroCPU cpu
inner join hostdetails host
on host.PKEY = cpu.pkey
and host.instanceNumber = cpu.instance_number
order by 1,2,3,4
) a
group by 1,2
) b
group by 1
)
select * from DBCPU;
END;
 
 
--Name: P_DS_CPU_CALC
--Description: Execute the procedures created above to create the table T_DS_CPU_CALC
call `projectID.dataset.P_DS_CPU_CALC`();
 
 
 
 
--Name: P_DS_BMS_sizing
--Description: This procedure will create the table T_DS_BMS_sizing.  This table will be used to size the BMS servers and storage for a given Oracle workload
Create or replace procedure `projectID.dataset.P_DS_BMS_sizing` ()
Begin
create or replace table `projectID.dataset.T_DS_BMS_sizing` as
--Version 2.0.1
--BMS Sizing
--Description:This query will evaluate the customer's on-premises environment and right-size the workload on BMS using the same on-premises server to database mapping
--On-premises host details
WITH hostdetails AS (
SELECT
    TRIM(dbinstances.pkey) AS PKEY,
     dbinstances.host_name as host_name,
     CAST(metrics._INSTANCE_NUMBER AS INT64) AS instanceNumber,
     MAX(CAST(metrics.NUM_CPU_CORES_CUMULATIVE_VALUE AS DECIMAL)) AS cores,
     MAX(CAST(metrics.PHYSICAL_MEMORY_BYTES_CUMULATIVE_VALUE AS DECIMAL)/1024/1024/1024) AS totalMemoryGB, 
FROM `projectID.dataset.awrhistosstat_rs_metrics` AS metrics
     INNER JOIN `projectID.dataset.dbinstances` AS dbinstances
             ON TRIM(metrics._PKEY) = TRIM(dbinstances.pkey)                                 
            AND CAST(metrics._INSTANCE_NUMBER AS INT64) = CAST(dbinstances.inst_id AS INT64) 
GROUP BY dbinstances.pkey,
         dbinstances.host_name,
         instanceNumber
            
),
DB_number AS --Identify the number of databases per servers
(
select dbinstances.host_name,count (instance_name) as Database_count
FROM `projectID.dataset.dbinstances` as dbinstances
group by dbinstances.host_name
),
--Database CPU Usage
--Description - Sum the DB CPUs for each host server by hour then find the peak hour
DBCPU AS (
SELECT *  FROM `projectID.dataset.T_DS_CPU_CALC`
),
--Database Storage Used
--Description: Find the total database storage needed per host.  For RAC databases count the storage once per RAC cluster
--Only datafiles size is used to determine storage size with no storage uplift
DBStorage AS
(
select DISTINCT
     dbsizing_facts._PKEY, dbinstances.host_name, dbsizing_facts._INSTANCE_NUMBER,
     --dbsizing_facts.DB_SIZE_ALLOCATED_GB,
     CAST(dbsizing_facts.DB_SIZE_ALLOCATED_GB as numeric)/1024 as DB_SIZE_ALLOCATED_GB
from `projectID.dataset.dbsizing_facts` AS dbsizing_facts
     inner join  `projectID.dataset.dbinstances` as dbinstances
             on trim(dbsizing_facts.pkey) = trim(dbinstances.pkey)
            and cast(dbsizing_facts._INSTANCE_NUMBER as INT64) = cast(dbinstances.inst_id as INT64)
            and cast(dbsizing_facts._HOUR as INT64) = 0
order by dbsizing_facts._PKEY, dbsizing_facts._INSTANCE_NUMBER
),
StorageRanking AS --Rank the data in order to only count the storage once per RAC cluster
(
SELECT
     host_name,
     _INSTANCE_NUMBER,
     CAST(DB_SIZE_ALLOCATED_GB AS NUMERIC) AS DB_SIZE_ALLOCATED_GB,
     RANK() OVER (PARTITION BY _PKEY
                  ORDER BY _PKEY, _INSTANCE_NUMBER) AS Ranking
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
SELECT
host_name
FROM StorageRanking
EXCEPT DISTINCT
SELECT
host_name
FROM StorageSizeSums
),
StorageFinalResults AS --Display the storage results counting the storage once per RAC cluster
(
SELECT
     host_name,
     CEIL(SUM(DB_SIZE_ALLOCATED_GB)) AS DB_size_TB,
FROM StorageSizeSums
GROUP BY
host_name
UNION ALL
SELECT
host_name, 0
FROM StorageMissing
ORDER BY host_name
),
--Database Memory Usage
DBMEMORY as(
Select --sum the database memory for each host
a.host_name,
round((sum(a.SGA_SIZE_GB) * 1.10)) as SGA_SIZE_GB --memory is uplifted 10% to account for growth
from
(SELECT --select the database memory required
dbparameters.PKEY,
dbparameters.inst_id,
hostdetails.host_name,
max(CAST(dbparameters.value as numeric))/1024/1024/1024 as SGA_SIZE_GB
FROM `projectID.dataset.dbparameters` as dbparameters
INNER JOIN hostdetails as hostdetails
ON TRIM(hostdetails.PKEY)=TRIM(dbparameters.PKEY)
and CAST(hostdetails.instanceNumber as numeric)=CAST(dbparameters.INST_ID as numeric)
and TRIM(dbparameters.name) in ( 'sga_target', 'memory_max_target', 'memory_target', 'sga_max_size')
group by 
dbparameters.PKEY,
dbparameters.inst_id,
hostdetails.host_name
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
FROM
(
 SELECT -- Step 1 -find the SUM of IOPS and MBps by database for each hour
  sysstat.pkey,
  dbid,
  hour,
  ROUND((SUM(physical_read_total_bytes_perc95) + SUM(physical_write_total_bytes_perc95))/1024/1024,2) iombps_total_perc95,
  SUM(physical_read_total_io_requests_perc95) + SUM(physical_write_total_io_req_perc95) iops_total_perc95,
FROM
  projectID.dataset.vsysstat_columnar  as sysstat
  JOIN projectID.dataset.vdbinstances as dbinstance
  ON sysstat.PKEY = dbinstance.PKEY AND sysstat.instance_number = dbinstance.inst_id
GROUP BY
  sysstat.pkey,
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
from
projectID.dataset.vsysstat_columnar  as sysstat
  JOIN projectID.dataset.vdbinstances as dbinstance
  ON sysstat.PKEY = dbinstance.PKEY AND sysstat.instance_number = dbinstance.inst_id
),
DBHostJoin as(
select  --Join the on-premises hosts to the databases
DBIO.*,
MIN(DBhostName.host_name) as host_name
from DBIO
inner join DBhostName using (PKEY)
group by 1,2,3
),
DBIOMissing AS
(
SELECT --Find which on-premises hosts are part of a RAC database
DISTINCT host_name
FROM DBHostName
EXCEPT DISTINCT
SELECT
DISTINCT host_name
FROM DBHostJoin
),
DBIOFinalResults AS
(
SELECT --Sum the results of the RAC databases for each host
     host_name,
     sum(DBHostjoin.iombps_total_perc95) as iombps_total_perc95,
     sum(DBHostjoin.iops_total_perc95) as iops_total_perc95,
FROM DBHostJoin
group by 1
UNION ALL
SELECT
host_name, 0, 0
FROM DBIOMissing
ORDER BY host_name
),
--Calculate Storage size based on on-premises performance requirements
--Description: Determine the required SSD and HT storage size required based on IOPS and MBp/s
--For SSD, QoS of 56 MBp/s and 7200 IOPS per TB was used (defined by BMS PM team)
--For HT, QoS of 900 MBp/s and 28800 per 4 TB was used
DBIO_sizing as(
Select
DBCPU.host_name,
StorageFinalResults.DB_size_TB,
CASE
when DBIOFinalResults.iops_total_perc95 = 0 or DBIOFinalResults.iombps_total_perc95 = 0 then 0
when DBIOFinalResults.iops_total_perc95 < 7200 and DBIOFinalResults.iombps_total_perc95 < 56 then CEIL(StorageFinalResults.DB_size_TB)
when DBIOFinalResults.iops_total_perc95/7200 > DBIOFinalResults.iombps_total_perc95/56 then CEIL(DBIOFinalResults.iops_total_perc95/7200)
else CEIL(DBIOFinalResults.iombps_total_perc95/56)
end as SSD_Storage_TB, --calcualte the SSD storage required
CASE
when DBIOFinalResults.iops_total_perc95 = 0 or DBIOFinalResults.iombps_total_perc95 = 0 then 0
when DBIOFinalResults.iops_total_perc95 < 28800 and DBIOFinalResults.iombps_total_perc95 < 900 AND CEIL(StorageFinalResults.DB_size_TB) < 16 then 1
when DBIOFinalResults.iops_total_perc95 < 28800 and DBIOFinalResults.iombps_total_perc95 < 900 AND CEIL(StorageFinalResults.DB_size_TB) > 16 then 1 + Trunc((StorageFinalResults.DB_size_TB)/16)
when CEIL(DBIOFinalResults.iops_total_perc95/28800) > CEIL(DBIOFinalResults.iombps_total_perc95/900) AND CEIL(StorageFinalResults.DB_size_TB) < 16 then CEIL(DBIOFinalResults.iops_total_perc95/28800)
when CEIL(DBIOFinalResults.iops_total_perc95/28800) < CEIL(DBIOFinalResults.iombps_total_perc95/900) AND CEIL(StorageFinalResults.DB_size_TB) < 16 then CEIL(DBIOFinalResults.iombps_total_perc95/900)
when CEIL(DBIOFinalResults.iops_total_perc95/28800) > CEIL(DBIOFinalResults.iombps_total_perc95/900) AND CEIL(StorageFinalResults.DB_size_TB) > 16 then CEIL(DBIOFinalResults.iops_total_perc95/28800)
when CEIL(DBIOFinalResults.iops_total_perc95/28800) < CEIL(DBIOFinalResults.iombps_total_perc95/900) AND CEIL(StorageFinalResults.DB_size_TB) > 16 then
(CASE
when Trunc((StorageFinalResults.DB_size_TB)/16) < CEIL(DBIOFinalResults.iombps_total_perc95/900) then CEIL(DBIOFinalResults.iombps_total_perc95/900)
when Trunc((StorageFinalResults.DB_size_TB)/16) > CEIL(DBIOFinalResults.iombps_total_perc95/900) then CEIL(DBIOFinalResults.iombps_total_perc95/900) + Trunc((StorageFinalResults.DB_size_TB)/16)
end)
else  0
end as High_Throughput_per_4TB, --calculate the HT storage required
from DBIOFinalResults as DBIOFinalResults
inner join DBCPU using (host_name)
inner join StorageFinalResults using (host_name)
),
--Calculate the BMS Pricing
DBPRICING
as
(
SELECT a.*,
machinesizes.EST_PRICE as BMS_Server_Price,
machinesizes.CORES as BMS_cores_count,
machinesizes.RAM_GB as BMS_memory
FROM
(SELECT
DBMEMORY.host_name,
DB_number.Database_count,
DBMEMORY.SGA_SIZE_GB,
DBCPU.DB_CPU_CORES,
DBCPU.Server_Cores,
CEIL(StorageFinalResults.DB_size_TB) as DB_size_TB,
DBIOFinalResults.iombps_total_perc95,
DBIOFinalResults.iops_total_perc95,
CASE --DB CPU is sized at the 75% capacity of the BMS server.
WHEN DBCPU.DB_CPU_CORES < 8*.75 AND DBMEMORY.SGA_SIZE_GB  < 192  THEN 'XS'
WHEN  DBCPU.DB_CPU_CORES < 8*.75 AND DBMEMORY.SGA_SIZE_GB  >= 192 and  DBMEMORY.SGA_SIZE_GB < 384 Then 'S'
WHEN  DBCPU.DB_CPU_CORES < 8*.75 AND DBMEMORY.SGA_SIZE_GB  >= 384 and  DBMEMORY.SGA_SIZE_GB < 768 Then 'M'
WHEN  DBCPU.DB_CPU_CORES < 8*.75 AND DBMEMORY.SGA_SIZE_GB  >= 768 and  DBMEMORY.SGA_SIZE_GB < 1536 Then 'L'
WHEN  DBCPU.DB_CPU_CORES < 8*.75 AND DBMEMORY.SGA_SIZE_GB  >= 1536 and  DBMEMORY.SGA_SIZE_GB < 3072 Then 'XL'
WHEN (DBCPU.DB_CPU_CORES >=  8*.75  AND DBCPU.DB_CPU_CORES <16*.75) AND DBMEMORY.SGA_SIZE_GB  < 384  THEN 'S'
WHEN (DBCPU.DB_CPU_CORES >=  8*.75  AND DBCPU.DB_CPU_CORES <16*.75) AND DBMEMORY.SGA_SIZE_GB  >= 384 and DBMEMORY.SGA_SIZE_GB < 768 THEN 'M'
WHEN (DBCPU.DB_CPU_CORES >=  8*.75  AND DBCPU.DB_CPU_CORES <16*.75) AND DBMEMORY.SGA_SIZE_GB  >= 768 and DBMEMORY.SGA_SIZE_GB < 1536 THEN 'L'
WHEN (DBCPU.DB_CPU_CORES >=  8*.75  AND DBCPU.DB_CPU_CORES <16*.75) AND DBMEMORY.SGA_SIZE_GB  >= 1536 and DBMEMORY.SGA_SIZE_GB < 3072 THEN 'XL'
WHEN (DBCPU.DB_CPU_CORES >=  16*.75  AND DBCPU.DB_CPU_CORES < 24*.75) AND DBMEMORY.SGA_SIZE_GB < 768 THEN 'M' 
 
WHEN ((DBCPU.DB_CPU_CORES >=  16*.75  AND DBCPU.DB_CPU_CORES < 24*.75) AND (DBMEMORY.SGA_SIZE_GB  >= 768 AND DBMEMORY.SGA_SIZE_GB < 1536)) THEN 'L'
WHEN ((DBCPU.DB_CPU_CORES >=  16*.75  AND DBCPU.DB_CPU_CORES < 24*.75) AND (DBMEMORY.SGA_SIZE_GB  >= 1536 AND DBMEMORY.SGA_SIZE_GB < 3072)) THEN 'XL'
WHEN (DBCPU.DB_CPU_CORES >=  24*.75  AND DBCPU.DB_CPU_CORES < 56*.75) AND DBMEMORY.SGA_SIZE_GB < 1536 THEN 'L'
WHEN ((DBCPU.DB_CPU_CORES >=  24*.75  AND DBCPU.DB_CPU_CORES < 56*.75) AND (DBMEMORY.SGA_SIZE_GB  >=1536 AND DBMEMORY.SGA_SIZE_GB  < 3072)) THEN 'XL'
WHEN (DBCPU.DB_CPU_CORES >=  56*.75  AND DBCPU.DB_CPU_CORES < 112*.75) AND DBMEMORY.SGA_SIZE_GB  < 3072 THEN 'XL'
ELSE  'No Match, please consolidate or distribute '
END AS BMS_Server_Size,
DBIO_sizing.SSD_Storage_TB,
DBIO_SIZING.SSD_Storage_TB * 115 as SSD_Storage_Price,
DBIO_SIZING.High_Throughput_per_4TB,
CASE
When DBIO_SIZING.High_Throughput_per_4TB = 0 then 0
When DBIO_SIZING.High_Throughput_per_4TB = CEIL(StorageFinalResults.DB_size_TB) AND DBIO_SIZING.High_Throughput_per_4TB <= 4  Then 828
When DBIO_SIZING.High_Throughput_per_4TB *4 >= CEIL(StorageFinalResults.DB_size_TB) Then DBIO_SIZING.High_Throughput_per_4TB * 828
When DBIO_SIZING.High_Throughput_per_4TB *4 <= CEIL(StorageFinalResults.DB_size_TB) Then ((CEIL(StorageFinalResults.DB_size_TB) - (DBIO_SIZING.High_Throughput_per_4TB *4)) * 84) + (828 * DBIO_SIZING.High_Throughput_per_4TB)
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
LEFT JOIN `projectID.dataset.optimusconfig_bms_machinesizes` AS machinesizes
ON machinesizes.MACHINE_SIZE_SHORT=BMS_Server_Size
),
--Calculate the Final BMS Pricing based on the preferred storage option
FinalTable as
(select
DBPRICING.*,
CASE
when High_Throughput_Pricing * 1.1 > SSD_Storage_Price then 'SSD' --Added 10% price guardrail as per Michelle (BMS PM)
when High_Throughput_Pricing *1.1 < SSD_Storage_Price then 'HT' --Added 10% price guardrail as per Michelle (BMS PM)
end as Perferred_storage,
CASE
when High_Throughput_Pricing = 0 then cast(BMS_Server_Price as numeric)
when High_Throughput_Pricing *1.1 > SSD_Storage_Price then cast(BMS_Server_Price as numeric) + cast(SSD_Storage_Price as numeric) --Added 10% price guardrail as per Michelle (BMS PM)
when High_Throughput_Pricing *1.1 < SSD_Storage_Price then cast(BMS_Server_Price as numeric) + cast(High_Throughput_Pricing as numeric) --Added 10% price guardrail as per Michelle (BMS PM)
end as Total_BMS_Price_using_HT_Storage,
cast(SSD_Storage_Price as numeric)+cast(BMS_Server_Price as numeric) Total_BMS_Price_using_SSD_Storage
from DBPRICING
)
select *,
CASE
when  Finaltable.DB_size_TB > (CEIL(High_Throughput_per_4TB * 4)) AND Perferred_storage = 'HT'  then CEIL(finalTable.DB_size_TB - (High_Throughput_per_4TB * 4))
else 0
end as High_Throughput_Additional_TB
from FinalTable
order by 1;
End;
 
 
--Name: P_DS_BMS_sizing
--Description: Execute the procedures created above to create the table T_DS_BMS_sizing
call `projectID.dataset.P_DS_BMS_sizing`();
 
 
--Name: P_DS_Database_Metrics
--Description: This procedure will create a table that will provide IOPS, MBps, CPU and memory metrics for each database within the workload.  You can use this data to manually consolidate an Oracle Workload
Create or replace procedure `projectID.dataset.P_DS_Database_Metrics` ()
Begin
Create or replace table `projectID.dataset.T_DS_Database_Metrics` as
WITH vcputimemodel as (
SELECT pkey, dbid, instance_number, hour,
    AVG(DB_CPU_PERC95) DB_CPU_PERC95,
    AVG(BACKG_CPU_TIME_PERC95) BACKG_CPU_TIME_PERC95,
    AVG(DB_TIME_PERC95) DB_TIME_PERC95,
    AVG(SQL_EXEC_ELAPS_TIME_PERC95) SQL_EXEC_ELAPS_TIME_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
PERCENTILE_CONT(DB_CPU_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS DB_CPU_PERC95,
PERCENTILE_CONT(BACKG_CPU_TIME_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS BACKG_CPU_TIME_PERC95,
PERCENTILE_CONT(DB_TIME_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS DB_TIME_PERC95,
PERCENTILE_CONT(SQL_EXEC_ELAPS_TIME_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS SQL_EXEC_ELAPS_TIME_PERC95,
FROM
 (
     SELECT pkey, dbid, instance_number, hour,
         CASE
           WHEN trim(a.stat_name) = 'DB CPU' then cast(perc95_value as numeric)
         END DB_CPU_PERC95,
         CASE
           WHEN trim(a.stat_name) = 'background cpu time' then cast(perc95_value as numeric)
         END BACKG_CPU_TIME_PERC95,
         CASE
           WHEN trim(a.stat_name) = 'DB time' then cast(perc95_value as numeric)
         END DB_TIME_PERC95,
         CASE
           WHEN trim(a.stat_name) = 'sql execute elapsed time' then cast(perc95_value as numeric)
         END SQL_EXEC_ELAPS_TIME_PERC95
     FROM `projectID.dataset.vdbahistsystimemodel` a
     WHERE TRIM(a.stat_name) IN ( 'DB CPU', 'background cpu time', 'DB time', 'sql execute elapsed time')
 ))
GROUP BY pkey, dbid, instance_number, hour
),
vcpusysstat AS (
SELECT pkey, dbid, instance_number, hour,
    AVG(RECURSIVE_CPU_PERC95) RECURSIVE_CPU_PERC95,
    AVG(PARSE_CPU_PERC95) PARSE_CPU_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
PERCENTILE_CONT(RECURSIVE_CPU_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS RECURSIVE_CPU_PERC95,
PERCENTILE_CONT(PARSE_CPU_PERC95, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS PARSE_CPU_PERC95,
FROM(
SELECT pkey, dbid, instance_number, hour,
        CASE
          WHEN trim(a.stat_name) = 'recursive cpu usage' then cast(perc95_value as numeric)
        END RECURSIVE_CPU_PERC95,
        CASE
          WHEN trim(a.stat_name) = 'parse time cpu' then cast(perc95_value as numeric)
        END PARSE_CPU_PERC95
FROM `projectID.dataset.vdbahistsysstat` a
WHERE TRIM(a.stat_name) IN ('recursive cpu usage', 'parse time cpu')))
GROUP BY pkey, dbid, instance_number, hour
),
vcpuosstat AS (
SELECT pkey, dbid, instance_number, hour,
    AVG(NUM_CPU_CORES_PERC95) NUM_CPU_CORES_PERC95,
    AVG(NUM_CPUS_PERC95) NUM_CPUS_PERC95,
    AVG(BUSY_TIME_PERC95) BUSY_TIME_PERC95,
    AVG(IDLE_TIME_PERC95) IDLE_TIME_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
PERCENTILE_CONT(NUM_CPU_CORES, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS NUM_CPU_CORES_PERC95,
PERCENTILE_CONT(NUM_CPUS, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS NUM_CPUS_PERC95,
PERCENTILE_CONT(BUSY_TIME, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS BUSY_TIME_PERC95,
PERCENTILE_CONT(IDLE_TIME, 0.95) OVER(partition by pkey, dbid, instance_number, hour) AS IDLE_TIME_PERC95,
FROM (
SELECT pkey, dbid, instance_number, hour,
        CASE
          WHEN trim(a.stat_name) = 'NUM_CPU_CORES' then cast(CUMULATIVE_VALUE as numeric)
        END NUM_CPU_CORES,
        CASE
          WHEN trim(a.stat_name) = 'NUM_CPUS' then cast(CUMULATIVE_VALUE as numeric)
        END NUM_CPUS,
        CASE
          WHEN trim(a.stat_name) = 'BUSY_TIME' then cast(perc95 as numeric)
        END BUSY_TIME,
        CASE
          WHEN trim(a.stat_name) = 'IDLE_TIME' then cast(perc95 as numeric)
        END IDLE_TIME,
FROM `projectID.dataset.awrhistosstat` a
WHERE TRIM(a.stat_name) IN ('NUM_CPU_CORES', 'NUM_CPUS', 'BUSY_TIME', 'IDLE_TIME')))
GROUP BY pkey, dbid, instance_number, hour
),
vhandlingzeroCPU AS (
SELECT tm.pkey, tm.dbid, tm.instance_number, tm.hour,
    ROUND((DB_CPU_PERC95/1000000),2) DB_CPU_P95_SECONDS,
    ROUND((BACKG_CPU_TIME_PERC95/1000000),2) BACKG_CPU_TIME_P95_SECONDS,
    ROUND((RECURSIVE_CPU_PERC95/100),2) RECURSIVE_CPU_P95_SECONDS,
    ROUND((PARSE_CPU_PERC95/100),2) PARSE_CPU_P95_SECONDS,
    ROUND(cast(BUSY_TIME_PERC95 as numeric)/100,2) OS_BUSY_TIME_P95_SECONDS,
    ROUND(cast(IDLE_TIME_PERC95 as numeric)/100,2) OS_IDLE_TIME_P95_SECONDS,
    ROUND(((DB_CPU_PERC95/1000000 + BACKG_CPU_TIME_PERC95/1000000)*100)/ (cast(BUSY_TIME_PERC95 as numeric)/100 + cast(IDLE_TIME_PERC95 as numeric)/100),2) DB_CPU_USAGE_PERCENTAGE,
    ROUND(((cast(BUSY_TIME_PERC95 as numeric)/100)*100)/(cast(BUSY_TIME_PERC95 as numeric)/100 + cast(IDLE_TIME_PERC95 as numeric)/100),2) HOST_CPU_USAGE_PERCENTAGE,
    NUM_CPU_CORES_PERC95,
    NUM_CPUS_PERC95,
    ROUND((cast(BUSY_TIME_PERC95 as numeric)/100 + cast(IDLE_TIME_PERC95 as numeric)/100)/cast(avg_snaps_diff_secs AS NUMERIC)) NUM_CPU_CORES_CALC_RVENG,
FROM vcputimemodel tm
INNER JOIN  vcpusysstat st
ON tm.pkey = st.pkey
AND tm.dbid = st.dbid
AND tm.instance_number = st.instance_number
AND tm.hour = st.hour
INNER JOIN  vcpuosstat os
ON trim(tm.pkey) = trim(os.pkey)
AND CAST(tm.dbid AS NUMERIC) = CAST(os.dbid AS NUMERIC)
AND CAST(tm.instance_number AS NUMERIC) = CAST(os.instance_number AS NUMERIC)
AND CAST(tm.hour AS NUMERIC) = CAST(os.hour AS NUMERIC)
INNER JOIN `projectID.dataset.awrsnapdetails` snp
ON tm.pkey = snp.pkey
AND tm.dbid = CAST(snp.dbid AS numeric)
AND tm.instance_number = CAST(snp.instance_number AS numeric)
AND tm.hour = CAST(snp.hour AS numeric)
ORDER BY tm.pkey, tm.dbid, tm.instance_number, tm.hour
),
DBCPU as
(
SELECT cpu.pkey, cpu.dbid, cpu.instance_number, cpu.hour,
    DB_CPU_USAGE_PERCENTAGE,
    HOST_CPU_USAGE_PERCENTAGE,
    ROUND(DB_CPU_USAGE_PERCENTAGE * (IF (NUM_CPU_CORES_PERC95 = 0, NUM_CPU_CORES_CALC_RVENG, NUM_CPU_CORES_PERC95))/100,2) DB_CPU_CORES,
    CEIL(HOST_CPU_USAGE_PERCENTAGE * (IF (NUM_CPU_CORES_PERC95 = 0, NUM_CPU_CORES_CALC_RVENG, NUM_CPU_CORES_PERC95))/100) HOST_CORES,
    NUM_CPU_CORES_PERC95,
    NUM_CPUS_PERC95,
    NUM_CPU_CORES_CALC_RVENG,
FROM vhandlingzeroCPU cpu
order by 1,2,3,4
),
FinalTable as
(
SELECT
sysstat.pkey,
sysstat.instance_number,
sysstat.hour,
dbsizing.DB_NAME,
execute_count_perc95,
physical_reads_perc95,
physical_reads_direct_perc95,
physical_writes_perc95,
CAST(DBCPU.DB_CPU_CORES as numeric) as DB_CPU_CORES_95,
ROUND((physical_read_total_bytes_perc95 + physical_write_total_bytes_perc95)/1024/1024,2) iombps_total_perc95,
(physical_read_total_io_requests_perc95 + physical_write_total_io_req_perc95) iops_total_perc95,
CAST(dbparameters.value as numeric)/1024/1024/1024 as SGA_SIZE_GB,
CASE
 when physical_reads_direct_perc95 = 0 then NULL
 else
 round(physical_reads_direct_perc95 / physical_reads_perc95 * 100,0)
 end as pct_direct_reads_perc95, --fts and parallel reads
CASE
 when cell_physical_io_bytes_eligible_for_predicate_offload_perc95 =0 then NULL
 else
 round(cell_physical_io_bytes_eligible_for_predicate_offload_perc95 / physical_read_total_bytes_perc95 * 100, 0)
 end as pct_eligible_io_for_smartcan_perc95, --eligible io for smartscan
CASE
 when cell_physical_io_bytes_saved_by_storage_index_perc95 =0 then NULL
 else round(cell_physical_io_bytes_saved_by_storage_index_perc95 / cell_physical_io_bytes_eligible_for_predicate_offload_perc95 * 100, 0)
 end as pct_storageindex_over_eligible_perc95, --storage index over smartscan eligible io
CASE
 when cell_physical_io_bytes_saved_by_storage_index_perc95=0 then NULL
 else round(cell_physical_io_bytes_saved_by_storage_index_perc95 / physical_read_total_bytes_perc95 * 100, 0)
 end as pct_storageindex_over_iototalbytes_perc95, --storage index over total io bytes
physical_read_total_bytes_perc95, -- Foregrounds Bytes Reads (Application Only)
physical_read_bytes_perc95, -- Foreground + Background Reads (Application + Database Utilities)
physical_read_bytes_perc95 / physical_read_total_bytes_perc95 * 100 pct_appbytesreads_over_totalbytesreads -- (Percent of Application Reads Over Total Reads)
FROM `projectID.dataset.vsysstat_columnar`  as sysstat
join `projectID.dataset.dbsizing_facts` as dbsizing
on sysstat.pkey = dbsizing._PKEY
and sysstat.instance_number = CAST(dbsizing._INSTANCE_NUMBER as numeric)
and sysstat.hour= CAST(dbsizing._HOUR as numeric)
join DBCPU on DBCPU.pkey = sysstat.pkey
and DBCPU.instance_number=sysstat.instance_number
and DBCPU.hour=sysstat.hour
join `projectID.dataset.dbparameters` as dbparameters
on dbsizing._PKEY = dbparameters.PKEY
and sysstat.instance_number = CAST(dbparameters.INST_ID as numeric)
where TRIM(dbparameters.name) = 'sga_target'
order by 1,3,2
)
select * from FinalTable;
End;
 
 
 
 
--Description: Execute the procedures created above to create the table T_DS_Database_Metrics
call `projectID.dataset.P_DS_Database_Metrics`();
 
 
--Name: V_DS_dbsummary
--Description: This view provides general details regarding each Oracle database
Create or replace view `projectID.dataset.V_DS_dbsummary` as
select a.*,
CASE
when a.DB_feature_usage = 'False' then 'Non-Exadata'
when a.DB_feature_usage = 'True' then 'Exadata'
else 'UNKOWN'
end as Is_Exadata
from
(SELECT DISTINCT
dbsummary.pkey,
dbsummary.dbid,
db_name,
cdb,
dbversion,
dbfullversion,
log_mode,
force_logging,
redo_gb_per_day,
CAST(rac_dbinstaces as numeric) as rac_dbinstaces,
characterset,
platform_name,
startup_time,
user_schemas,
CAST(buffer_cache_mb as numeric) as buffer_cache_mb,
CAST(shared_pool_mb as numeric) as shared_pool_mb,
CAST(total_pga_allocated_mb as numeric) as total_pga_allocated_mb,
CAST(db_size_allocated_gb as numeric) as db_size_allocated_gb,
CAST(db_size_in_use_gb as numeric) as db_size_in_use_gb,
db_long_size_gb,dg_database_role,
dg_protection_mode,dg_protection_level,
IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')) Begin_date,
IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')) End_date,
DATE_DIFF(IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.max_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')),
          IFNULL(SAFE_CAST(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,8)) as DATE  format 'DD-MON-YY'), SAFE_CAST(REPLACE(TRIM(SUBSTR(TRIM(awr.min_begin_interval_time),1,10)), '.', '-') as DATE  format 'DD-MM-YYYY')), DAY) as AWR_collected_days,
features.name as DB_feature_name,
features.current_usage as DB_feature_usage
FROM `projectID.dataset.dbsummary` as dbsummary
inner join `projectID.dataset.awrsnapdetails` as awr using (PKEY)
inner join `projectID.dataset.dbfeatures` as features using (PKEY)
--ON dbsummary.PKEY = awr.PKEY
where awr.hour="14"
and features.name like '%Exadata%'
) a
;
 
 
 
--Name: V_DS_BMS_BOM
--Description: This view build the BMS BOM required for this Oracle workload
create or replace view `projectID.dataset.V_DS_BMS_BOM` as
With bms_servers
as
(
select bms_server_size,
count(BMS_Server_size) as Count,
from `projectID.dataset.T_DS_BMS_sizing` as BMSsizing
group by BMS_Server_size
),
BOM
as
(select
CASE
when bms_server_size = 'XS' then '8 CORE 192 GB DRAM'
when bms_server_size = 'S' then '16 CORE 384 GB DRAM'
when bms_server_size = 'M' then '24 CORE 768 GB DRAM'
when bms_server_size = 'L' then '56 CORE 1536 GB DRAM'
when bms_server_size = 'XL' then '112 CORE 3072 GB DRAM'
end as BMS_SKU,
bms_servers.count
from bms_servers
),
SSD_storage
as
(select
sum(SSD_Storage_TB) as SSD_Storage_TB
from  `projectID.dataset.T_DS_BMS_sizing` as BMSsizing
where Perferred_storage='SSD'
),
HT_storage
as
(select sum(High_Throughput_per_4TB) as High_Throughput_per_4TB
from  `projectID.dataset.T_DS_BMS_sizing` as BMSsizing
where Perferred_storage='HT'
),
HT_storage_add
as
(
select
CASE
when  DB_size_TB > (CEIL(High_Throughput_per_4TB * 4)) then CEIL(DB_size_TB - (High_Throughput_per_4TB * 4))
else 0
end as High_Throughput_additional
from  `projectID.dataset.T_DS_BMS_sizing` as BMSsizing
where Perferred_storage='HT'
),
FinalTable
as
(
select * from BOM
union all
select 'All SSD Storage / TB',SSD_Storage_TB
from SSD_storage
union all
select 'HT SSD Storage (Initial 4TB)', High_Throughput_per_4TB
from HT_storage
union all
select 'HT SSD Storage (Additional 1TB)', sum(High_Throughput_additional)
from HT_storage_add
order by 1
)
select * from FinalTable;
 
 
 
--Name: V_DS_dbfeatures
--Description: This view lists the Oracle features used by each database
create or replace view  `projectID.dataset.V_DS_dbfeatures` as
SELECT
pkey,
con_id,
name,
current_usage,
CAST(detected_usage as numeric) as detected_usage,
total_samples,
first_usage,
last_usage,
aux_count
FROM projectID.dataset.dbfeatures;
--Name: V_DS_HostDetails
--Description: This view displays the server on-premises metrics
Create or replace view `projectID.dataset.V_DS_HostDetails` as
WITH hostdetails AS
(
 SELECT  
 b.pkey,  
 b.host_name,  
 CAST(a._INSTANCE_NUMBER AS INT64) AS instanceNumber,  
 MAX(CAST(a.NUM_CPU_CORES_CUMULATIVE_VALUE AS DECIMAL)) AS cores,  
 MAX(CAST(a.PHYSICAL_MEMORY_BYTES_CUMULATIVE_VALUE AS DECIMAL)) AS totalMemory,     
 MAX(CAST(a.HOST_CPU_UTILIZATION AS DECIMAL)) AS maxHOSTCPUUtilizationPercentage,  
 AVG(CAST(a.HOST_CPU_UTILIZATION AS DECIMAL)) AS avgHOSTCPUUtilizationPercentage,
 FROM    projectID.dataset.awrhistosstat_rs_metrics a,    projectID.dataset.dbinstances b
 WHERE    TRIM(a._PKEY)=TRIM(b.pkey)  
 AND CAST(a._INSTANCE_NUMBER AS INT64)= CAST(b.inst_id AS INT64)
 GROUP BY    b.pkey,    b.host_name,    instanceNumber
 ),
 db_details AS
 (
   SELECT  
   DISTINCT a.pkey,  
   a.db_name,  
   a.cdb AS iscdb,  
   a.redo_gb_per_day,  
   a.rac_dbinstaces,  
   a.platform_name,  
   a.db_size_allocated_gb,  
   a.db_size_in_use_gb,  
   a.dg_database_role,  
   a.dg_protection_level
   FROM    projectID.dataset.dbsummary a
   ),
 
   sourceSizing AS
   (  SELECT  
   a.PKEY,  
   a.db_name,  
   b.host_name,  
   b.instanceNumber,  
   a.iscdb,  
   a.redo_gb_per_day,
   IF    (CAST(a.rac_dbinstaces AS INT64) > 1,      TRUE,      FALSE) AS isRacDB,  
   a.platform_name,  
   CAST(a.db_size_allocated_gb AS NUMERIC) AS db_size_allocated_gb,  
   CAST(a.db_size_in_use_gb AS NUMERIC) AS db_size_in_use_gb,  
   SUM(b.cores) AS cores,  
   SUM(b.totalMemory) AS totalMemory,    
   MAX(b.maxHOSTCPUUtilizationPercentage) AS maxHostCPUUtilizationPercentage,  
   AVG(b.avgHOSTCPUUtilizationPercentage) AS avgHostCPUUtilizationPercentage
   FROM    db_details a,  
   hostdetails b
   WHERE    TRIM(a.PKEY)=TRIM(b.pkey)
   GROUP BY    1,    2,    3,    4,    5,    6,    7,    8,    9,    10
    )
 
   select * from sourceSizing order by host_name;
 
-- End of script
-------------------------------------------------------------------------------------
 
 
 
 
 
--end of script
--------------------------------------------------------------------------------------

