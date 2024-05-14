-- name: readiness-check-init-get-db-count$
select count(*) as db_count
from collection_postgres_all_databases;

-- name:  readiness-check-init-get-execution-id$
select 'postgres_' || current_setting('server_version_num') || '_' || to_char(current_timestamp, 'YYYYMMDDHH24MISSMS') as execution_id;

-- name:  readiness-check-init-get-source-id$
select system_identifier::VARCHAR as source_id
from pg_control_system();
