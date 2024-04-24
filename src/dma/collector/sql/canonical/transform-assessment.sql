-- name: transformation-01-assessment-ddl!
create or replace table database_summary(
        database_name varchar,
        database_type varchar,
        database_version varchar
    );

-- name: transformation-01-readiness-check-ddl!
create or replace table alloydb_readiness_check_summary(
        severity ENUM ('INFO', 'WARNING', 'ERROR'),
        info varchar
    );
