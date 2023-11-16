with user_tables as (
    select t.relid as object_id,
        t.relname as table_name,
        t.schemaname as schema_name,
        pg_total_relation_size(t.relid) as total_object_size_mb,
        pg_relation_size(t.relid) as object_size_mb,
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
table_stats as (
    select s.relid as object_id,
        s.schemaname as schema_name,
        s.relname as table_name,
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
        n.nspname as table_schema,
        c.relname as table_name,
        s.srvname as foreign_server_name
    from pg_catalog.pg_foreign_table ft
        inner join pg_catalog.pg_class c on c.oid = ft.ftrelid
        inner join pg_catalog.pg_namespace n on n.oid = c.relnamespace
        inner join pg_catalog.pg_foreign_server s on s.oid = ft.ftserver
    where pg_catalog.pg_table_is_visible(c.oid)
),
src as (
    select t.object_id,
        case
            when f.object_id is not null then 'FOREIGN TABLE'
            else 'TABLE'
        end as table_type,
        t.table_name,
        t.schema_name,
        t.total_object_size_mb,
        t.object_size_mb,
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
        s.heap_blocks_hit,
        s.heap_blocks_read,
        s.index_blocks_hit,
        s.index_blocks_read,
        s.toast_blocks_hit,
        s.toast_blocks_read,
        s.toast_index_hit,
        s.toast_index_read
    from user_tables t
        left join table_stats s on (t.object_id = s.object_id)
        left join foreign_tables f on (t.object_id = s.object_id)
)
select chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
    src.object_id,
    src.schema_name,
    src.table_type,
    src.table_name,
    src.total_object_size_mb,
    src.object_size_mb,
    src.sequence_scan,
    src.live_tuples,
    src.dead_tuples,
    src.modifications_since_last_analyzed,
    src.modifications_since_last_analyzed,
    src.last_analyzed,
    src.last_autoanalyzed,
    src.last_autovacuumed,
    src.last_vacuumed,
    src.vacuum_count,
    src.analyze_count,
    src.autoanalyze_count,
    src.autovacuum_count,
    src.foreign_server_name,
    src.heap_blocks_hit,
    src.heap_blocks_read,
    src.index_blocks_hit,
    src.index_blocks_read,
    src.toast_blocks_hit,
    src.toast_blocks_read,
    src.toast_index_hit,
    src.toast_index_read
from src;
