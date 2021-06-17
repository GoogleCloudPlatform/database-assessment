SELECT   a.ckey,
         a.db_name,
         a.cdb,
         a.dbversion,
         a.db_size_allocated_gb,
         a.network_to_gcp,
         a.target_env_creation_hour,
         a.subtotal_3x_migration,
         a.pos_migration_monitoring_hour,
         (a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour)                                                                                                            subtotal_hour,
         ROUND((a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) * 0.25,0)                                                                                            project_management_hours,
         (a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) + ROUND((a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) * 0.25,0) total_migration_hours
FROM     (
                SELECT a.*,
                       subtotal_simple_migration_hour + old_dbversion_complex_factor subtotal_migration_hour,
                       8                                                             target_env_creation_hour,
                       CASE
                              WHEN db_size_allocated_gb < 1000 THEN 2
                              WHEN db_size_allocated_gb >= 1000
                              AND    db_size_allocated_gb <= 5000 THEN 4
                              WHEN db_size_allocated_gb >= 5000 THEN 8
                       END                                                                      pos_migration_monitoring_hour,
                       ROUND((subtotal_simple_migration_hour + old_dbversion_complex_factor)*3) subtotal_3x_migration
                FROM   (
                              SELECT a.*,
                                     CASE
                                            WHEN CAST(SUBSTR(REPLACE(dbversion,'.',''),0,5) AS NUMERIC) < 11204 THEN subtotal_simple_migration_hour  * 0.8
                                            WHEN CAST(SUBSTR(REPLACE(dbversion,'.',''),0,5) AS NUMERIC) = 11204 THEN subtotal_simple_migration_hour  * 0.2
                                            WHEN CAST(SUBSTR(REPLACE(dbversion,'.',''),0,5) AS NUMERIC) <= 12201 THEN subtotal_simple_migration_hour * 0.1
                                            WHEN CAST(SUBSTR(REPLACE(dbversion,'.',''),0,5) AS NUMERIC) > 12201 THEN 0
                                     END old_dbversion_complex_factor
                              FROM   (
                                            SELECT a.*,
                                                   a.time_to_exportbackup_locally_hour + a.time_to_transfer_to_gcp_hour + a.time_to_importrestore_hour + a.time_to_validate_migration_hour subtotal_simple_migration_hour
                                            FROM   (
                                                              SELECT     a.ckey,
                                                                         a.db_name,
                                                                         a.cdb,
                                                                         a.dbversion,
                                                                         a.db_size_allocated_gb,
                                                                         b.network_to_gcp,
                                                                         b.gbytes_per_sec,
                                                                         ROUND(a.db_size_allocated_gb / c.gbytes_per_sec / 60 / 60,2)     time_to_exportbackup_locally_hour,
                                                                         ROUND(a.db_size_allocated_gb / b.gbytes_per_sec / 60 / 60,2)     time_to_transfer_to_gcp_hour,
                                                                         ROUND(a.db_size_allocated_gb / c.gbytes_per_sec / 60 / 60,2)*2.5 time_to_importrestore_hour,
                                                                         1                                                                time_to_validate_migration_hour
                                                              FROM       ${dataset}.vdbsummary a
                                                              cross join ${dataset}.vconfig_networktogcp b
                                                              cross join
                                                                         (
                                                                                SELECT network_to_gcp,
                                                                                       gbytes_per_sec
                                                                                FROM   ${dataset}.vconfig_networktogcp
                                                                                WHERE  network_to_gcp = 'To SSD') c ) a ) a ) a ) a
WHERE    a.network_to_gcp != 'To SSD'
ORDER BY ckey,
         time_to_transfer_to_gcp_hour;
