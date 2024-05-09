-- name: readiness-check-init-postgres-get-db-count$
select count(*) as db_count
from collection_postgres_all_databases;

-- name: get-replication-slot-count$
select c.setting_value
from collection_postgres_settings c
where c.setting_name = 'max_replication_slots';

-- name: get-used-replication-slot-count$
select used_replication_slots
from collection_used_replication_slots;

-- name: get-max-wal-senders$
select c.setting_value
from collection_postgres_settings c
where c.setting_name = 'max_wal_senders';

-- name: get-max-worker-processes$
select c.setting_value
from collection_postgres_settings c
where c.setting_name = 'max_worker_processes';
