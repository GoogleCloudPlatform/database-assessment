\o output/opdb__tablesbyschema_:VTAG.csv
SELECT n.nspname AS "Schema", /* for foreign tables */ c.relname AS "Table",
                                                       s.srvname AS "Server"
FROM pg_catalog.pg_foreign_table ft
INNER JOIN pg_catalog.pg_class c ON c.oid = ft.ftrelid
INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
INNER JOIN pg_catalog.pg_foreign_server s ON s.oid = ft.ftserver
WHERE pg_catalog.pg_table_is_visible(c.oid)
ORDER BY 1,
         2
