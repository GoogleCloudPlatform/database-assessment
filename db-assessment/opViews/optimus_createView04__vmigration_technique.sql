SELECT db_name,
       CAST(SUBSTR(dbversion,0,2) AS NUMERIC) dbversionshort,
       dbversion,
       dbfullversion,
       (
              SELECT TRIM(value)
              FROM   mydataset.dbparameters a
              WHERE  trim(con_id) = '1'
              AND    trim(name) = 'compatible' limit 1) compatible,
       log_mode,
       redo_gb_per_day,
       platform_name,
       db_size_allocated_gb,
       db_size_in_use_gb,
       dg_protection_level,
       CASE
              WHEN db_size_allocated_gb < 1000 THEN 'Data Pump or Exp/Imp (Imports data first, then indexes)'
              WHEN db_size_allocated_gb > 1000
              AND    IF(cast(instr(dbfullversion,'Standard') AS NUMERIC) > 0, 'Standard', 'Enterprise') = 'Enterprise'
              AND    cast(substr(dbversion,0,1) AS NUMERIC) >= 11
              AND    platform_name IN ('Microsoft Windows (32-bit)',
                                       'Microsoft Windows (x86)',
                                       'Microsoft Windows 64-bit for AMD',
                                       'Microsoft Windows (x86-64)',
                                       'Microsoft Windows IA (64-bit)',
                                       'Microsoft Windows (64-bit Itanium)',
                                       'Linux 64-bit for AMD',
                                       'Linux x86 64-bit',
                                       'Solaris Operating System (AMD64)',
                                       'Solaris Operating System (x86-64)') THEN 'Oracle Physical Dataguard'
              WHEN db_size_allocated_gb > 1000
              AND    IF(cast(instr(dbfullversion,'Standard') AS NUMERIC) > 0, 'Standard', 'Enterprise') = 'Enterprise'
              AND    cast(substr(dbversion,0,1) AS NUMERIC) >= 10
              AND    platform_name IN ('Linux (32-bit)',
                                       'Linux x86',
                                       'Linux IA (64-bit)',
                                       'Linux Itanium') THEN 'Oracle Physical Dataguard'
              WHEN db_size_allocated_gb > 1000
              AND    IF(cast(instr(dbfullversion,'Standard') AS NUMERIC) > 0, 'Standard', 'Enterprise') = 'Standard' THEN 'Data Pump or Exp/Imp (Imports data first, then indexes) or RMAN (Backup/Restore w/ Optimized Downtime)'
              WHEN db_size_allocated_gb > 1000
              AND    platform_name != 'Linux x86 64-bit' THEN 'Oracle TTS Cross Platform w/ Optimized Downtime'
       END                                                               initial_recommended_migration_technique_to_same_dbversion,
       'References: Doc ID 413484.1, Doc ID 1401921.1, Doc ID 2005729.1' oracle_references,
       ''                                                                other_references
FROM   mydataset.vdbsummary a;
