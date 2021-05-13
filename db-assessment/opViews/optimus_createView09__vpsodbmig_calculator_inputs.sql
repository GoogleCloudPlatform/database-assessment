SELECT db_size_allocated_gb database_size,
       CASE
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 2) = '21' THEN '21c'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 2) = '19' THEN '19c'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 2) = '18' THEN '18c'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 3) = '122' THEN '12c'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 5) = '12102' THEN
         '12.1.0.2'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 5) = '11204' THEN
         '11.2.0.4'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 2) = '11' THEN '11g'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 2) = '10' THEN '10g'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 1) = '9' THEN '9i'
         WHEN SUBSTR(REPLACE(dbversion, '.', ''), 0, 1) = '8' THEN '8i'
       END                  source_database_version,
       IF(CAST(INSTR(dbfullversion, 'Standard') AS NUMERIC) > 0, 'Standard',
       'Enterprise')        database_edition,
       platform_name        source_os_platform,
       ''                   for_more_information
FROM   ${dataset}.vdbsummary; 
