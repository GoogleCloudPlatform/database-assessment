-- name: assessment-alloydb-01-assessment-pglogical-extension-check!
insert into alloydb_readiness_check_summary (severity, info)
select 'ERROR',
    'pglogical extension not installed on the database'
where (
        select count(*) = 0
        from collection_postgres_extensions
        where extension_name = 'pglogical'
    );

-- name: no-assessment-alloydb-01-table_count!
insert into alloydb_readiness_check_summary (severity, info)
select 'ERROR',
    'detected ' || a.unsupported_foreign_table_count || ' foreign tables.'
from (
        select count(distinct ft.ftrelid) total_foreign_table_count,
            count(
                distinct case
                    when w.fdwname = ANY (ARRAY ['oracle_fdw', 'orafdw']) then ft.ftrelid
                    else null
                end
            ) as supported_foreign_table_count,
            count(
                distinct case
                    when w.fdwname != all (ARRAY ['oracle_fdw', 'orafdw']) then ft.ftrelid
                    else null
                end
            ) as unsupported_foreign_table_count
        from collection_postgres_calculated_metrics ft
    ) a
where a.unsupported_foreign_table_count > 0
