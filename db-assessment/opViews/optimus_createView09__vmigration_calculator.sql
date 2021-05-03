select a.ckey, a.db_name, a.cdb, a.dbversion, a.db_size_allocated_gb, a.network_to_gcp, a.target_env_creation_hour, a.subtotal_3x_migration, a.pos_migration_monitoring_hour, 
       (a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) subtotal_hour, round((a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) * 0.25,0) project_management_hours,
       (a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) + round((a.target_env_creation_hour + a.subtotal_3x_migration + a.pos_migration_monitoring_hour) * 0.25,0) total_migration_hours
from (
select a.*,
        subtotal_simple_migration_hour + old_dbversion_complex_factor subtotal_migration_hour,
        8 target_env_creation_hour,
        case
            when db_size_allocated_gb < 1000 then 2
            when db_size_allocated_gb >= 1000 and  db_size_allocated_gb <= 5000 then 4
            when db_size_allocated_gb >= 5000 then 8
        end pos_migration_monitoring_hour,
        round((subtotal_simple_migration_hour + old_dbversion_complex_factor)*3) subtotal_3x_migration
from (
select a.*,
    case 
        when cast(substr(replace(dbversion,'.',''),0,5) as numeric) < 11204 then subtotal_simple_migration_hour * 0.8
        when cast(substr(replace(dbversion,'.',''),0,5) as numeric) = 11204 then subtotal_simple_migration_hour * 0.2
        when cast(substr(replace(dbversion,'.',''),0,5) as numeric) <= 12201 then subtotal_simple_migration_hour * 0.1
        when cast(substr(replace(dbversion,'.',''),0,5) as numeric) > 12201 then 0
    end old_dbversion_complex_factor
from (
select a.*, 
    a.time_to_exportbackup_locally_hour + a.time_to_transfer_to_gcp_hour + a.time_to_importrestore_hour + a.time_to_validate_migration_hour subtotal_simple_migration_hour
from (
select a.ckey, a.db_name, a.cdb, a.dbversion, a.db_size_allocated_gb, b.network_to_gcp, b.gbytes_per_sec,
       round(a.db_size_allocated_gb / c.gbytes_per_sec / 60 / 60,2) time_to_exportbackup_locally_hour,
       round(a.db_size_allocated_gb / b.gbytes_per_sec / 60 / 60,2) time_to_transfer_to_gcp_hour,
       round(a.db_size_allocated_gb / c.gbytes_per_sec / 60 / 60,2)*2.5 time_to_importrestore_hour,
       1 time_to_validate_migration_hour
from `MYDATASET.vdbsummary` a
cross join `MYDATASET.vconfig_networktogcp` b
cross join (select network_to_gcp, gbytes_per_sec from `MYDATASET.vconfig_networktogcp` where network_to_gcp = 'To SSD') c
) a
) a
) a
) a
where a.network_to_gcp != 'To SSD'
order by ckey, time_to_transfer_to_gcp_hour;
