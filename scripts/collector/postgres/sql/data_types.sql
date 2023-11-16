with table_columns as (
  select n.nspname::TEXT as table_schema,
    case
      c.relkind
      when 'r'::"char" then 'TABLE'::text
      when 'v'::"char" then 'VIEW'::text
      when 'm'::"char" then 'MATERIALIZED_VIEW'::text
      when 'S'::"char" then 'SEQUENCE'::text
      when 'f'::"char" then 'FOREIGN_TABLE'::text
      when 'p'::"char" then 'PARTITIONED_TABLE'::text
      when 'c'::"char" then 'COMPOSITE_TYPE'::text
      when 'I'::"char" then 'PARTITIONED INDEX'::text
      when 't'::"char" then 'TOAST_TABLE'::text
      else 'UNCATEGORIZED'::text
    end as table_type,
    c.relname::TEXT as table_name,
    a.attname::TEXT as column_name,
    t.typname::TEXT as data_type
  from pg_attribute a
    join pg_class c on a.attrelid = c.oid
    join pg_namespace n on n.oid = c.relnamespace
    join pg_type t on a.atttypid = t.oid
  where a.attnum > 0
    and (
      n.nspname <> all (
        ARRAY ['pg_catalog'::name, 'information_schema'::name]
      )
      and n.nspname !~ '^pg_toast'::text
    )
    and (
      c.relkind = ANY (
        ARRAY ['r'::"char", 'p'::"char", 'S'::"char", 'v'::"char", 'f'::"char", 'm'::"char",'c'::"char",'I'::"char",'t'::"char"]
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
