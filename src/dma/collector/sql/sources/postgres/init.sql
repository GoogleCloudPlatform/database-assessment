-- name: init-get-db-version$
select current_setting('server_version_num')::VARCHAR as db_version;

-- name: init-get-execution-id$
select 'postgres_' || current_setting('server_version_num') || '_' || to_char(current_timestamp, 'YYYYMMDDHH24MISSMS') as execution_id;

-- name: init-get-source-id$
select system_identifier::VARCHAR as source_id
from pg_control_system();
