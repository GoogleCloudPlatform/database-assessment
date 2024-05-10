-- name: ddl-01-readiness-check-ddl!
create or replace table database_summary(
    collection_key varchar,
    database_name varchar,
    database_type varchar,
    database_version varchar
  );

create or replace table readiness_check_summary(
    migration_target ENUM (
      'CLOUDSQL',
      'ALLOYDB',
      'BMS',
      'SPANNER',
      'BIGQUERY'
    ),
    severity ENUM ('INFO', 'WARNING', 'ERROR', 'PASS'),
    rule_code varchar,
    info varchar
  );
