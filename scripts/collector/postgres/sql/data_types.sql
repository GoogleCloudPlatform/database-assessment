with table_columns as (
  select n.nspname as table_schema,
    case
      c.relkind
      when 'r' then 'TABLE'
      when 'v' then 'VIEW'
      when 'm' then 'MATERIALIZED_VIEW'
      when 'S' then 'SEQUENCE'
      when 'f' then 'FOREIGN_TABLE'
      when 'p' then 'PARTITIONED_TABLE'
      when 'c' then 'COMPOSITE_TYPE'
      when 'I' then 'PARTITIONED INDEX'
      when 't' then 'TOAST_TABLE'
      else 'UNCATEGORIZED'
    end as table_type,
    c.relname as table_name,
    a.attname as column_name,
    t.typname as data_type
  from pg_attribute a
    join pg_class c on a.attrelid = c.oid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_type t on a.atttypid = t.oid
  where a.attnum > 0
    and (
      n.nspname <> all (
        ARRAY ['pg_catalog', 'information_schema']
      )
      and n.nspname !~ '^pg_toast'
    )
    and (
      c.relkind = ANY (
        ARRAY ['r', 'p', 'S', 'v', 'f', 'm','c','I','t']
      )
    )
),
src as (
  select a.table_schema,
    a.table_type,
    a.table_name,
    a.data_type,
    count(a.data_type) as data_type_count
  from table_columns a
  group by a.table_schema,
    a.table_type,
    a.table_name,
    a.data_type
)
select chr(39) || :DMA_SOURCE_ID || chr(39) as pkey,
  chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
  chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
  src.table_schema,
  src.table_type,
  src.table_name,
  src.data_type,
  src.data_type_count
from src
