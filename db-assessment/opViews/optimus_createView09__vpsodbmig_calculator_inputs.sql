select db_size_allocated_gb database_size, 
        case 
            when substr(replace(dbversion,'.',''),0,2) = '21' then '21c'
            when substr(replace(dbversion,'.',''),0,2) = '19' then '19c'
            when substr(replace(dbversion,'.',''),0,2) = '18' then '18c'
            when  substr(replace(dbversion,'.',''),0,3) ='122' then '12c'
            when  substr(replace(dbversion,'.',''),0,5) ='12102' then '12.1.0.2'
            when  substr(replace(dbversion,'.',''),0,5) ='11204' then '11.2.0.4'
            when substr(replace(dbversion,'.',''),0,2) = '11' then '11g'
            when substr(replace(dbversion,'.',''),0,2) = '10' then '10g'
            when substr(replace(dbversion,'.',''),0,1) = '9' then '9i'
            when substr(replace(dbversion,'.',''),0,1) = '8' then '8i'
        end source_database_version
       , if(cast(instr(dbfullversion,'Standard') as numeric) > 0, 'Standard', 'Enterprise') database_edition, platform_name source_os_platform,
       'go/oracle-to-oracle-db-migration-calculator' for_more_information
from `MYDATASET.vdbsummary`;
