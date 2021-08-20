  -- database overall
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
  a.dg_protection_level,
FROM
  `<project_id>.<dataset_name>.dbsummary` a ;

  -- migration details
SELECT
  distinct a.pkey,
  a.db_name,
  a.TECHNIQUE,
  a.NETWORK_TO_GCP,
  ROUND( CAST(a.TIME_TO_BACKUP_TO_DISK_HOUR AS DECIMAL)) AS TIME_TO_BACKUP_TO_DISK_HOUR,
  ROUND( CAST(a.TIME_TO_TRANSFER_BACKUP_OVER_NETWORK_HOUR AS DECIMAL)) AS TIME_TO_TRANSFER_BACKUP_OVER_NETWORK_HOUR,
  ROUND( CAST(a.TIME_TO_RESTORE_BACKUP_HOUR AS DECIMAL)) AS TIME_TO_RESTORE_BACKUP_HOUR,
  ROUND( CAST(a.TIME_TO_RESTORE_INCR_7DAY_BKP_HOUR AS DECIMAL)) AS TIME_TO_RESTORE_INCR_7DAY_BKP_HOUR,
  ROUND( CAST(a.REQUIRED_DB_DOWNTIME_HOURS AS DECIMAL)) AS REQUIRED_DB_DOWNTIME_HOURS
FROM
  `<project_id>.<dataset_name>.dbmigration_details` a ; 

  -- Source Sizing
WITH
  hostdetails AS (
  SELECT
    b.pkey,
    b.host_name,
    CAST(a._INSTANCE_NUMBER AS INT64) AS instanceNumber,
    MAX(CAST(a.NUM_CPUS_PERC95 AS DECIMAL)) AS cores,
    MAX(CAST(a.PHYSICAL_MEMORY_BYTES_PERC95 AS DECIMAL)) AS totalMemory,
    MAX(CAST(a.PHYSICAL_MEMORY_BYTES_PERC95 AS DECIMAL))-MAX(CAST(a.FREE_MEMORY_BYTES_PERC95 AS DECIMAL)) AS usedmemory,
    MAX(CAST(a.HOST_CPU_UTILIZATION AS DECIMAL)) AS maxHOSTCPUUtilizationPercentage,
    AVG(CAST(a.HOST_CPU_UTILIZATION AS DECIMAL)) AS avgHOSTCPUUtilizationPercentage,
  FROM
    `<project_id>.<dataset_name>.awrhistosstat_rs_metrics` a,
    `<project_id>.<dataset_name>.dbinstances` b
  WHERE
    a._PKEY=b.pkey
    AND CAST(a._INSTANCE_NUMBER AS INT64)= CAST(b.inst_id AS INT64)
  GROUP BY
    b.pkey,
    b.host_name,
    instanceNumber ),
  db_details AS (
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
  FROM
    `<project_id>.<dataset_name>.dbsummary` a ),
  sourceSizing AS (
  SELECT
    a.PKEY,
    a.db_name,
    b.host_name,
    b.instanceNumber,
    a.iscdb,
    a.redo_gb_per_day,
  IF
    (CAST(a.rac_dbinstaces AS INT64) > 1,
      TRUE,
      FALSE) AS isRacDB,
    a.platform_name,
    CAST(a.db_size_allocated_gb AS NUMERIC) AS db_size_allocated_gb,
    CAST(a.db_size_in_use_gb AS NUMERIC) AS db_size_in_use_gb,
    SUM(b.cores) AS cores,
    SUM(b.totalMemory) AS totalMemory,
    SUM(b.usedmemory) AS usedmemory,
    MAX(b.maxHOSTCPUUtilizationPercentage) AS maxHostCPUUtilizationPercentage,
    AVG(b.avgHOSTCPUUtilizationPercentage) AS avgHostCPUUtilizationPercentage
  FROM
    db_details a,
    hostdetails b
  WHERE
    a.PKEY=b.pkey
  GROUP BY
    1,
    2,
    3,
    4,
    5,
    6,
    7,
    8,
    9,
    10 ),
  --BMS Sizing by Host
  BMSSizing AS (
  SELECT
    *
  FROM (
    SELECT
      _pkey,
      instanceNumber,
      SUM(sourceDBCores) AS totalSourceDBCores,
      MAX(sourceHostCores) AS totalSourceCores,
      MAX(sourceTotalMemoryGB) AS totalSourceMemoryGB,
      SUM(storageTB) AS totalBMSStorageTB,
      SUM(dbCPU) AS totalBMSDbCPU,
      SUM(hostCPU) AS totalBMSHostCPU,
      SUM(dbMemory) AS totalBMSDbMemory,
    FROM (
      SELECT
        _PKEY,
        _DBID,
        DB_NAME,
        CAST(_INSTANCE_NUMBER AS INT64) AS instanceNumber,
        ROUND(MAX(CAST(CPUDB95_CORES AS NUMERIC))) sourceDBCores,
        ROUND(MAX(CAST(FREE_MEMORY_BYTES_PERC95 AS NUMERIC))) sourcefreeMemory,
        ROUND(MAX(CAST(PHYSICAL_MEMORY_BYTES_PERC95 AS NUMERIC)/1024/1024/1024)) sourceTotalMemoryGB,
        ROUND(MAX(CAST(NUM_CPUS_PERC95 AS NUMERIC))) sourceHostCores,
        ROUND(MAX(CAST(BMSSTORAGE_TB_DB AS NUMERIC))) storageTB,
        ROUND(MAX(CAST(BMSCORES95_DB AS NUMERIC))) dbCPU,
        ROUND(MAX(CAST(BMSCORES95_HOST AS NUMERIC))) hostCPU,
        ROUND(MAX(CAST(BMSMEMORY_GB_DB AS NUMERIC))) dbMemory
      FROM
        `<project_id>.<dataset_name>.dbsizing_facts`
      GROUP BY
        _PKEY,
        _DBID,
        instanceNumber,
        DB_NAME )
    GROUP BY
      _PKEY,
      instanceNumber ) ),
  sizingSummary AS (
  SELECT
    b.db_name,
    b.host_name,
    b.instanceNumber,
    b.isRacDB,
    b.platform_name,
    b.db_size_allocated_gb,
    b.db_size_in_use_gb,
    b.cores AS sourceCores,
    b.totalMemory,
    b.usedmemory,
    b.maxHostCPUUtilizationPercentage,
    b.avgHostCPUUtilizationPercentage,
    a.totalBMSStorageTB,
    totalBMSHostCPU,
    totalBMSDbMemory,
  FROM
    BMSSizing a,
    sourceSizing b
  WHERE
    a._PKEY=b.PKEY
    AND a.instanceNumber = b.instanceNumber
  ORDER BY
    b.host_name )


      select * from sourceSizing order by host_name;
SELECT
  *,
IF
  (BMSServerConfig = 'XS',
    1850,
  IF
    (BMSServerConfig='S',
      2000,
    IF
      (BMSServerConfig='M',
        2400,
      IF
        (BMSServerConfig='L',
          3400,
        IF
          (BMSServerConfig='XL',
            6800,
            -1))))) AS BMSServerCost,
  totalBMSStorageTB*115 as BMSStorageFlashCost
FROM (
  SELECT
    *,
    CASE
      WHEN totalBMSHostCPU <=10 THEN 'XS'
      WHEN totalBMSHostCPU>10
    AND totalBMSHostCPU<=19 THEN 'S'
      WHEN totalBMSHostCPU>19 AND totalBMSHostCPU<=30 THEN 'M'
      WHEN totalBMSHostCPU>30
    AND totalBMSHostCPU<=48 THEN 'L With OVM/OLVM hard partitioned'
      WHEN totalBMSHostCPU>48 AND totalBMSHostCPU<=60 THEN 'L'
      WHEN totalBMSHostCPU>60
    AND totalBMSHostCPU<=105 THEN 'XL With OVM/OLVM hard partitioned'
      WHEN totalBMSHostCPU>105 AND totalBMSHostCPU<=120 THEN 'XL'
    ELSE
    'No Match, please consolidate or distribute '
  END
    AS BMSServerConfig
  FROM (
    SELECT
      host_name,
      SUM(db_size_allocated_gb) AS totalStotageGB,
      SUM(db_size_in_use_gb) AS totalUsedStorageGB,
      MAX(sourceCores) AS totalSourceCores,
      MAX(totalMemory) AS totalMemory,
      SUM(usedmemory) AS totalusedmemory,
      MAX(maxHostCPUUtilizationPercentage) AS maxHostCPUUtilizationPercentage,
      MAX(avgHostCPUUtilizationPercentage) AS avgHostCPUUtilizationPercentage,
      SUM(totalBMSStorageTB) AS totalBMSStorageTB,
      SUM(totalBMSHostCPU) AS totalBMSHostCPU,
      SUM(totalBMSDbMemory) AS totalBMSDbMemory
    FROM
      sizingSummary
    GROUP BY
      host_name
      order by host_name ) );
