-- name: collection-postgres-pglogical-privileges
with src as
(
    SELECT 
        pg_catalog.has_schema_privilege('pglogical', 'USAGE') as has_schema_usage_privilege,
        pg_catalog.has_table_privilege('"pglogical"."tables"', 'SELECT') as has_tables_select_privilege,
        pg_catalog.has_table_privilege('"pglogical"."local_node"', 'SELECT') as has_local_node_select_privilege,
        pg_catalog.has_table_privilege('"pglogical"."node"', 'SELECT') as has_node_select_privilege,
        pg_catalog.has_table_privilege('"pglogical"."node_interface"', 'SELECT') as has_node_interface_select_privilege
    From pg_extension where extname = 'pglogical'
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.has_schema_usage_privilege,
    src.has_tables_select_privilege,
    src.has_local_node_select_privilege,
    src.has_node_select_privilege,
    src.has_node_interface_select_privilege,
    current_database() as database_name
from src;

-- name: collection-postgres-user-schemas-without-privilege
with src as
(
    SELECT nspname 
	FROM pg_catalog.pg_namespace 
	WHERE nspname not in ('information_schema', 'pglogical','pglogical_origin')
	AND nspname not like 'pg\_%%' 
	AND pg_catalog.has_schema_privilege(nspname, 'USAGE') = 'f'
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.nspname as namespace_name,
    current_database() as database_name
from src;

-- name: collection-postgres-user-tables-without-privilege
with src as
(
    SELECT schemaname, tablename 
    FROM pg_catalog.pg_tables 
    WHERE 
        schemaname not in ('information_schema', 'pglogical', 'pglogical_origin') 
        AND schemaname not like 'pg\_%%' 
        AND pg_catalog.has_table_privilege(quote_ident(schemaname) || '.' || quote_ident(tablename), 'SELECT') = 'f'
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.schemaname as schema_name,
    src.tablename as table_name,
    current_database() as database_name
from src;


-- name: collection-postgres-user-views-without-privilege
with src as
(
    SELECT schemaname, viewname 
	FROM pg_catalog.pg_views 
	WHERE
        schemaname not in ('information_schema', 'pglogical', 'pglogical_origin') 
	    AND schemaname not like 'pg\_%%' 
	    AND pg_catalog.has_table_privilege(quote_ident(schemaname) || '.' || quote_ident(viewname), 'SELECT') = 'f'
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.schemaname as schema_name,
    src.viewname as view_name,
    current_database() as database_name
from src;

-- name: collection-postgres-user-sequences-without-privilege
with src as 
(
    SELECT n.nspname as nspname, relname 
	FROM pg_catalog.pg_class c 
	LEFT JOIN pg_catalog.pg_namespace n 
	ON n.oid = c.relnamespace 
	WHERE c.relkind='S' 
	    AND n.nspname != 'pglogical' 
	    AND n.nspname != 'pglogical_origin' 
	    AND n.nspname not like 'pg\_%%' AND pg_catalog.has_sequence_privilege(quote_ident(n.nspname) || '.' || quote_ident(relname), 'SELECT') = 'f'
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.nspname as namespace_name,
    src.relname as rel_name,
    current_database() as database_name
from src;