-- name: transformation-01-readiness-check-ddl!
create or replace table database_summary(
    collection_key varchar,
    database_name varchar,
    database_type varchar,
    database_version varchar
  );

create or replace table readiness_check_summary(
    collection_key varchar,
    migration_target ENUM (
      'CLOUDSQL',
      'ALLOYDB',
      'BMS',
      'SPANNER',
      'BIGQUERY'
    ),
    severity ENUM ('INFO', 'WARNING', 'ERROR', 'PASS'),
    assessment_type varchar,
    info varchar
  );

-- name: readiness-check-rules-01-
select current_setting('server_version_num')::VARCHAR as db_version;

-- name: init-readiness-check-get-execution-id$
select 'postgres_' || current_setting('server_version_num') || '_' || to_char(current_timestamp, 'YYYYMMDDHH24MISSMS') as execution_id;

-- name: init-get-source-id$
select system_identifier::VARCHAR as source_id
from pg_control_system();
