\ o output / opdb__foreign_tables_by_schema_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
    n.nspname as table_schema,
    /* for foreign tables */
    c.relname as table_name,
    s.srvname AS foreign_server_name
FROM pg_catalog.pg_foreign_table ft
    INNER JOIN pg_catalog.pg_class c ON c.oid = ft.ftrelid
    INNER JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
    INNER JOIN pg_catalog.pg_foreign_server s ON s.oid = ft.ftserver
WHERE pg_catalog.pg_table_is_visible(c.oid)
ORDER BY 1,
    2
