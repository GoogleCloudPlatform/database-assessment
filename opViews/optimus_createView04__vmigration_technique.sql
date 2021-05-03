select db_name, cast(substr(dbversion,0,2) as numeric) dbversionshort, dbversion, dbfullversion,
        (select trim(value) from `MYDATASET.dbparameters` a 
            where trim(con_id) = '1' and trim(name) = 'compatible' limit 1) compatible,
        log_mode, redo_gb_per_day, platform_name, db_size_allocated_gb, db_size_in_use_gb, dg_protection_level,
       case
            when db_size_allocated_gb < 1000 then 'Data Pump or Exp/Imp (Imports data first, then indexes)'
            when db_size_allocated_gb > 1000 and if(cast(instr(dbfullversion,'Standard') as numeric) > 0, 'Standard', 'Enterprise') = 'Enterprise' and cast(substr(dbversion,0,1) as numeric) >= 11 and platform_name 
                in ('Microsoft Windows (32-bit)','Microsoft Windows (x86)','Microsoft Windows 64-bit for AMD','Microsoft Windows (x86-64)','Microsoft Windows IA (64-bit)',
                'Microsoft Windows (64-bit Itanium)','Linux 64-bit for AMD','Linux x86 64-bit','Solaris Operating System (AMD64)','Solaris Operating System (x86-64)') then 'Oracle Physical Dataguard'
            when db_size_allocated_gb > 1000 and if(cast(instr(dbfullversion,'Standard') as numeric) > 0, 'Standard', 'Enterprise') = 'Enterprise' and cast(substr(dbversion,0,1) as numeric) >= 10 and platform_name 
                in ('Linux (32-bit)','Linux x86','Linux IA (64-bit)','Linux Itanium') then 'Oracle Physical Dataguard'
            when db_size_allocated_gb > 1000 and if(cast(instr(dbfullversion,'Standard') as numeric) > 0, 'Standard', 'Enterprise') = 'Standard' then 'Data Pump or Exp/Imp (Imports data first, then indexes) or RMAN (Backup/Restore w/ Optimized Downtime)'
            when db_size_allocated_gb > 1000 and platform_name != 'Linux x86 64-bit' then 'Oracle TTS Cross Platform w/ Optimized Downtime'
        end initial_recommended_migration_technique_to_same_dbversion,
        'References: Doc ID 413484.1, Doc ID 1401921.1, Doc ID 2005729.1' oracle_references,
	'' other_references
from `MYDATASET.vdbsummary` a;
