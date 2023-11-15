\ o output / opdb__pg_table_details_ :VTAG.csv;


with src as (
    select t.relid as object_id,
        t.relname as table_name,
        t.schemaname as schema_name,
        pg_total_relation_size(t.relid) AS total_object_size_mb,
        pg_relation_size(t.relid) AS object_size_mb,
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
    FROM pg_stat_user_tables t
)
SELECT chr(39) || :PKEY || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
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
    src.autovacuum_count
from src;
