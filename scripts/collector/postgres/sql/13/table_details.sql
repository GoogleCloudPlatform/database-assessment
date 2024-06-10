/*
 Copyright 2024 Google LLC

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 https://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
with all_objects as (
  select c.oid as object_id,
    case
      when c.relkind = 'r' then 'TABLE'
      when c.relkind = 'v' then 'VIEW'
      when c.relkind = 'm' then 'MATERIALIZED_VIEW'
      when c.relkind = 'S' then 'SEQUENCE'
      when c.relkind = 'f' then 'FOREIGN_TABLE'
      when c.relkind = 'p' then 'PARTITIONED_TABLE'
      when c.relkind = 'c' then 'COMPOSITE_TYPE'
      when c.relkind = 'I'
      and c.relname !~ '^pg_toast' then 'PARTITIONED_INDEX'
      when c.relkind = 'I'
      and c.relname ~ '^pg_toast' then 'TOAST_PARTITIONED_INDEX'
      when c.relkind = 'i'
      and c.relname !~ '^pg_toast' then 'INDEX'
      when c.relkind = 'i'
      and c.relname ~ '^pg_toast' then 'TOAST_INDEX'
      when c.relkind = 't' then 'TOAST_TABLE'
      else 'UNCATEGORIZED'
    end as object_type,
    ns.nspname as object_schema,
    c.relname as object_name
  from pg_class c
    join pg_catalog.pg_namespace as ns on (c.relnamespace = ns.oid)
  where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
    and ns.nspname !~ '^pg_toast'
    and c.relkind = ANY (
      ARRAY ['r', 'p', 'S', 'v', 'f', 'm','c','I','t']
    )
),
stat_user_tables as (
  select t.relid as object_id,
    pg_total_relation_size(t.relid) as total_object_size_bytes,
    pg_relation_size(t.relid) as object_size_bytes,
    t.seq_scan as sequence_scan,
    t.n_live_tup as live_tuples,
    t.n_dead_tup as dead_tuples,
    t.n_mod_since_analyze as modifications_since_last_analyzed,
    t.n_ins_since_vacuum as inserts_since_last_vacuumed,
    t.last_analyze as last_analyzed,
    t.last_autoanalyze as last_autoanalyzed,
    t.last_autovacuum as last_autovacuumed,
    t.last_vacuum as last_vacuumed,
    t.vacuum_count as vacuum_count,
    t.analyze_count as analyze_count,
    t.autoanalyze_count as autoanalyze_count,
    t.autovacuum_count as autovacuum_count
  from pg_stat_user_tables t
),
statio_user_tables as (
  select s.relid as object_id,
    s.heap_blks_hit as heap_blocks_hit,
    s.heap_blks_read as heap_blocks_read,
    s.idx_blks_hit as index_blocks_hit,
    s.idx_blks_read as index_blocks_read,
    s.toast_blks_hit as toast_blocks_hit,
    s.toast_blks_read as toast_blocks_read,
    s.tidx_blks_hit as toast_index_hit,
    s.tidx_blks_read as toast_index_read
  from pg_statio_user_tables s
),
foreign_tables as (
  select ft.ftrelid as object_id,
    s.srvname as foreign_server_name,
    w.fdwname as foreign_data_wrapper_name
  from pg_catalog.pg_foreign_table ft
    inner join pg_catalog.pg_class c on c.oid = ft.ftrelid
    inner join pg_catalog.pg_foreign_server s on s.oid = ft.ftserver
    inner join pg_catalog.pg_foreign_data_wrapper w on s.srvfdw = w.oid
),
src as (
  select t.object_id,
    a.object_type as table_type,
    a.object_name as table_name,
    a.object_schema as table_schema,
    t.total_object_size_bytes,
    t.object_size_bytes,
    t.sequence_scan,
    t.live_tuples,
    t.dead_tuples,
    t.modifications_since_last_analyzed,
    t.inserts_since_last_vacuumed,
    t.last_analyzed,
    t.last_autoanalyzed,
    t.last_autovacuumed,
    t.last_vacuumed,
    t.vacuum_count,
    t.analyze_count,
    t.autoanalyze_count,
    t.autovacuum_count,
    f.foreign_server_name,
    f.foreign_data_wrapper_name,
    s.heap_blocks_hit,
    s.heap_blocks_read,
    s.index_blocks_hit,
    s.index_blocks_read,
    s.toast_blocks_hit,
    s.toast_blocks_read,
    s.toast_index_hit,
    s.toast_index_read
  from all_objects a
    left join stat_user_tables t on (a.object_id = t.object_id)
    left join statio_user_tables s on (a.object_id = s.object_id)
    left join foreign_tables f on (a.object_id = f.object_id)
)
select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  chr(34) || src.object_id || chr(34) as object_id,
  chr(34) || replace(src.table_schema, chr(34), chr(30)) || chr(34) as table_schema,
  chr(34) || src.table_type || chr(34) as table_type,
  chr(34) || replace(src.table_name, chr(34), chr(39)) || chr(34) as table_name,
  src.total_object_size_bytes as total_object_size_bytes,
  src.object_size_bytes as object_size_bytes,
  src.sequence_scan as sequence_scan,
  chr(34) || src.live_tuples || chr(34) as live_tuples,
  chr(34) || src.dead_tuples || chr(34) as dead_tuples,
  src.modifications_since_last_analyzed as modifications_since_last_analyzed,
  chr(34) || src.last_analyzed || chr(34) as last_analyzed,
  chr(34) || src.last_autoanalyzed || chr(34) as last_autoanalyzed,
  chr(34) || src.last_autovacuumed || chr(34) as last_autovacuumed,
  chr(34) || src.last_vacuumed || chr(34) as last_vacuumed,
  src.vacuum_count as vacuum_count,
  src.analyze_count as analyze_count,
  src.autoanalyze_count as autoanalyze_count,
  src.autovacuum_count as autovacuum_count,
  chr(34) || src.foreign_server_name || chr(34) as foreign_server_name,
  chr(34) || src.foreign_data_wrapper_name || chr(34) as foreign_data_wrapper_name,
  COALESCE(src.heap_blocks_hit, 0) as heap_blocks_hit,
  COALESCE(src.heap_blocks_read, 0) as heap_blocks_read,
  COALESCE(src.index_blocks_hit, 0) as index_blocks_hit,
  COALESCE(src.index_blocks_read, 0) as index_blocks_read,
  COALESCE(src.toast_blocks_hit, 0) as toast_blocks_hit,
  COALESCE(src.toast_blocks_read, 0) as toast_blocks_read,
  COALESCE(src.toast_index_hit, 0) as toast_index_hit,
  COALESCE(src.toast_index_read, 0) as toast_index_read,
  chr(34) || current_database() || chr(34) as database_name
from src;
