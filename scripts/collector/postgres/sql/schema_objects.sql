with all_tables as (
  select c.oid as object_id,
    'TABLE' as object_category,
    case
      when c.relkind = 'r' then 'TABLE'
      when c.relkind = 'S' then 'SEQUENCE'
      when c.relkind = 'f' then 'FOREIGN_TABLE'
      when c.relkind = 'p' then 'PARTITIONED_TABLE'
      when c.relkind = 'c' then 'COMPOSITE_TYPE'
      when c.relkind = 't' then 'TOAST_TABLE'
      else 'UNCATEGORIZED_TABLE'
    end as object_type,
    ns.nspname as object_schema,
    c.relname as object_name,
    pg_get_userbyid(c.relowner) as object_database
  from pg_class c
    join pg_catalog.pg_namespace as ns on (c.relnamespace = ns.oid)
  where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
    and ns.nspname !~ '^pg_toast'
    and c.relkind = ANY (ARRAY ['r', 'p', 'S', 'f', 'c','t'])
),
all_views as (
  select c.oid as object_id,
    'VIEW' as object_category,
    case
      when c.relkind = 'v' then 'VIEW'
      when c.relkind = 'm' then 'MATERIALIZED_VIEW'
      else 'UNCATEGORIZED_VIEW'
    end as object_type,
    ns.nspname as object_schema,
    c.relname as object_name,
    pg_get_userbyid(c.relowner) as object_database
  from pg_class c
    join pg_catalog.pg_namespace as ns on (c.relnamespace = ns.oid)
  where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
    and ns.nspname !~ '^pg_toast'
    and c.relkind = ANY (ARRAY [ 'v', 'm'])
),
all_indexes as (
  select i.indexrelid as object_id,
    'INDEX' as object_category,
    case
      when c.relkind = 'I'
      and c.relname !~ '^pg_toast' then 'PARTITIONED_INDEX'
      when c.relkind = 'I'
      and c.relname ~ '^pg_toast' then 'TOAST_PARTITIONED_INDEX'
      when c.relkind = 'i'
      and c.relname !~ '^pg_toast' then 'INDEX'
      when c.relkind = 'i'
      and c.relname ~ '^pg_toast' then 'TOAST_INDEX'
      else 'UNCATEGORIZED_INDEX'
    end as object_type,
    sut.relname as object_owner,
    sut.schemaname as object_schema,
    c.relname as object_name,
    pg_get_userbyid(c.relowner) as object_database
  from pg_index i
    join pg_stat_user_tables sut on (i.indrelid = sut.relid)
    join pg_class c on (i.indexrelid = c.oid)
),
src as (
  select a.object_database,
    a.object_category,
    a.object_type,
    a.object_schema,
    a.object_name,
    a.object_id
  from all_tables a
  union all
  select a.object_database,
    a.object_category,
    a.object_type,
    a.object_schema,
    a.object_name,
    a.object_id
  from all_views a
  union all
  select a.object_database,
    a.object_category,
    a.object_type,
    a.object_schema,
    a.object_name,
    a.object_id
  from all_indexes a
)
select chr(39) || :DMA_SOURCE_ID || chr(39) as pkey,
  chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
  chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
  src.object_database,
  src.object_category,
  src.object_type,
  src.object_schema,
  src.object_name,
  src.object_id
from src;
