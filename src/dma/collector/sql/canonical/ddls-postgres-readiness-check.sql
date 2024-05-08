-- name: ddl-postgres-02-readiness_check!
create or replace table postgres_database_summary(
    database_name varchar,
    database_type varchar,
    database_version varchar,
    database_size numeric
  );

create or replace table alloydb_readiness_check_summary(
    severity ENUM ('INFO', 'WARNING', 'ERROR'),
    assessment_type varchar,
    info varchar
  );
