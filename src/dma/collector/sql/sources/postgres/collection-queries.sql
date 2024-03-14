-- name: collection-postgres-applications
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    application_name as application_name,
    count(*) as application_count
from pg_stat_activity
group by :PKEY,
    :DMA_SOURCE_ID,
    :DMA_MANUAL_ID,
    application_name;

-- name: collection-postgres-aws-extension-dependency
with proc_alias1 as (
    select distinct n.nspname as function_schema,
        p.proname as function_name,
        l.lanname as function_language,
        (
            select 'Y'
            from pg_trigger
            where tgfoid = (n.nspname || '.' || p.proname)::regproc
        ) as Trigger_Func,
        lower(pg_get_functiondef(p.oid)::text) as def
    from pg_proc p
        left join pg_namespace n on p.pronamespace = n.oid
        left join pg_language l on p.prolang = l.oid
        left join pg_type t on t.oid = p.prorettype
    where n.nspname not in (
            'pg_catalog',
            'information_schema',
            'aws_oracle_ext'
        )
        and p.prokind not in ('a', 'w', 'f')
        and l.lanname in ('sql', 'plpgsql')
    order by function_schema,
        function_name
),
proc_alias2 as (
    select proc_alias1.function_schema,
        proc_alias1.function_name,
        proc_alias1.function_language,
        proc_alias1.Trigger_Func,
        proc_alias2.*
    from proc_alias1
        cross join LATERAL (
            select i as funcname,
                cntgroup as cnt
            from (
                    select (
                            regexp_matches(
                                proc_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1] i,
                        count(1) cntgroup
                    group by (
                            regexp_matches(
                                proc_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1]
                ) t
        ) as proc_alias2
    where def ~* 'aws_oracle_ext.*'
),
tbl_alias1 as (
    select alias1.proname,
        ns.nspname,
        case
            when relkind = 'r' then 'TABLE'
        end as objType,
        depend.relname,
        pg_get_expr(pg_attrdef.adbin, pg_attrdef.adrelid) as def
    from pg_depend
        inner join (
            select distinct pg_proc.oid as procoid,
                nspname || '.' || proname as proname,
                pg_namespace.oid
            from pg_namespace,
                pg_proc
            where nspname = 'aws_oracle_ext'
                and pg_proc.pronamespace = pg_namespace.oid
        ) alias1 on pg_depend.refobjid = alias1.procoid
        inner join pg_attrdef on pg_attrdef.oid = pg_depend.objid
        inner join pg_class depend on depend.oid = pg_attrdef.adrelid
        inner join pg_namespace ns on ns.oid = depend.relnamespace
),
tbl_alias2 as (
    select tbl_alias1.nspname as SCHEMA,
        tbl_alias1.relname as TABLE_NAME,
        alias2.*
    from tbl_alias1
        cross join LATERAL (
            select i as funcname,
                cntgroup as cnt
            from (
                    select (
                            regexp_matches(
                                tbl_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1] i,
                        count(1) cntgroup
                    group by (
                            regexp_matches(
                                tbl_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1]
                ) t
        ) as alias2
    where def ~* 'aws_oracle_ext.*'
),
constraint_alias1 as (
    select pgc.conname as CONSTRAINT_NAME,
        ccu.table_schema as table_schema,
        ccu.table_name,
        ccu.column_name,
        pg_get_constraintdef(pgc.oid) as def
    from pg_constraint pgc
        join pg_namespace nsp on nsp.oid = pgc.connamespace
        join pg_class cls on pgc.conrelid = cls.oid
        left join information_schema.constraint_column_usage ccu on pgc.conname = ccu.constraint_name
        and nsp.nspname = ccu.constraint_schema
    where contype = 'c'
    order by pgc.conname
),
constraint_alias2 as (
    select constraint_alias1.table_schema,
        constraint_alias1.constraint_name,
        constraint_alias1.table_name,
        constraint_alias1.column_name,
        alias2.*
    from constraint_alias1
        cross join LATERAL (
            select i as funcname,
                cntgroup as cnt
            from (
                    select (
                            regexp_matches(
                                constraint_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1] i,
                        count(1) cntgroup
                    group by (
                            regexp_matches(
                                constraint_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1]
                ) t
        ) as alias2
    where def ~* 'aws_oracle_ext.*'
),
index_alias1 as (
    select alias1.proname,
        nspname,
        case
            when relkind = 'i' then 'INDEX'
        end as objType,
        depend.relname,
        pg_get_indexdef(depend.oid) def
    from pg_depend
        inner join (
            select distinct pg_proc.oid as procoid,
                nspname || '.' || proname as proname,
                pg_namespace.oid
            from pg_namespace,
                pg_proc
            where nspname = 'aws_oracle_ext'
                and pg_proc.pronamespace = pg_namespace.oid
        ) alias1 on pg_depend.refobjid = alias1.procoid
        inner join pg_class depend on depend.oid = pg_depend.objid
        inner join pg_namespace ns on ns.oid = depend.relnamespace
    where relkind = 'i'
),
index_alias2 as (
    select index_alias1.nspname as SCHEMA,
        index_alias1.relname as IndexName,
        alias2.*
    from index_alias1
        cross join LATERAL (
            select i as funcname,
                cntgroup as cnt
            from (
                    select (
                            regexp_matches(
                                index_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1] i,
                        count(1) cntgroup
                    group by (
                            regexp_matches(
                                index_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1]
                ) t
        ) as alias2
    where def ~* 'aws_oracle_ext.*'
),
view_alias1 as (
    select alias1.proname,
        nspname,
        case
            when depend.relkind = 'v' then 'VIEW'
        end as objType,
        depend.relname,
        pg_get_viewdef(depend.oid) def
    from pg_depend
        inner join (
            select distinct pg_proc.oid as procoid,
                nspname || '.' || proname as proname,
                pg_namespace.oid
            from pg_namespace,
                pg_proc
            where nspname = 'aws_oracle_ext'
                and pg_proc.pronamespace = pg_namespace.oid
        ) alias1 on pg_depend.refobjid = alias1.procoid
        inner join pg_rewrite on pg_rewrite.oid = pg_depend.objid
        inner join pg_class depend on depend.oid = pg_rewrite.ev_class
        inner join pg_namespace ns on ns.oid = depend.relnamespace
    where not exists (
            select 1
            from pg_namespace
            where pg_namespace.oid = depend.relnamespace
                and nspname = 'aws_oracle_ext'
        )
),
view_alias2 as (
    select view_alias1.nspname as SCHEMA,
        view_alias1.relname as ViewName,
        alias2.*
    from view_alias1
        cross join LATERAL (
            select i as funcname,
                cntgroup as cnt
            from (
                    select (
                            regexp_matches(
                                view_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1] i,
                        count(1) cntgroup
                    group by (
                            regexp_matches(
                                view_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1]
                ) t
        ) as alias2
    where def ~* 'aws_oracle_ext.*'
),
trigger_alias1 as (
    select distinct n.nspname as function_schema,
        p.proname as function_name,
        l.lanname as function_language,
        (
            select 'Y'
            from pg_trigger
            where tgfoid = (n.nspname || '.' || p.proname)::regproc
        ) as Trigger_Func,
        lower(pg_get_functiondef(p.oid)::text) as def
    from pg_proc p
        left join pg_namespace n on p.pronamespace = n.oid
        left join pg_language l on p.prolang = l.oid
        left join pg_type t on t.oid = p.prorettype
    where n.nspname not in (
            'pg_catalog',
            'information_schema',
            'aws_oracle_ext'
        )
        and p.prokind not in ('a', 'w')
        and l.lanname in ('sql', 'plpgsql')
    order by function_schema,
        function_name
),
trigger_alias2 as (
    select trigger_alias1.function_schema,
        trigger_alias1.function_name,
        trigger_alias1.function_language,
        trigger_alias1.Trigger_Func,
        alias2.*
    from trigger_alias1
        cross join LATERAL (
            select i as funcname,
                cntgroup as cnt
            from (
                    select (
                            regexp_matches(
                                trigger_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1] i,
                        count(1) cntgroup
                    group by (
                            regexp_matches(
                                trigger_alias1.def,
                                'aws_oracle_ext[.][a-z]*[_,a-z,$,"]*',
                                'ig'
                            )
                        ) [1]
                ) t
        ) as alias2
    where def ~* 'aws_oracle_ext.*'
        and Trigger_Func = 'Y'
),
src as (
    select tbl_alias2.schema as schemaName,
        'N/A' as LANGUAGE,
        'TableDefaultConstraints' as type,
        tbl_alias2.table_name as typeName,
        tbl_alias2.funcname as AWSExtensionDependency,
        sum(cnt) as SCTFunctionReferenceCount
    from tbl_alias2
    group by tbl_alias2.schema,
        tbl_alias2.table_name,
        tbl_alias2.funcname
    union
    select function_schema as object_schema_name,
        function_language as object_language,
        'Procedures' as object_type,
        function_name as object_name,
        funcname as aws_extension_dependency,
        sum(cnt) as sct_function_reference_count
    from proc_alias2
    where 1 = 1
    group by function_schema,
        function_language,
        function_name,
        funcname
    union
    select constraint_alias2.table_schema as schemaName,
        'N/A' as LANGUAGE,
        'TableCheckConstraints' as type,
        constraint_alias2.table_name as typeName,
        constraint_alias2.funcname as AWSExtensionDependency,
        sum(cnt) as SCTFunctionReferenceCount
    from constraint_alias2
    group by constraint_alias2.table_schema,
        constraint_alias2.table_name,
        constraint_alias2.funcname
    union
    select index_alias2.Schema as schemaName,
        'N/A' as LANGUAGE,
        'TableIndexesAsFunctions' as type,
        index_alias2.IndexName as typeName,
        index_alias2.funcname as AWSExtensionDependency,
        sum(cnt) as SCTFunctionReferenceCount
    from index_alias2
    group by index_alias2.Schema,
        index_alias2.IndexName,
        index_alias2.funcname
    union
    select view_alias2.Schema as schemaName,
        'N/A' as LANGUAGE,
        'Views' as type,
        view_alias2.ViewName as typeName,
        view_alias2.funcname as AWSExtensionDependency,
        sum(cnt) as SCTFunctionReferenceCount
    from view_alias2
    group by view_alias2.Schema,
        view_alias2.ViewName,
        view_alias2.funcname
    union
    select function_schema as schemaName,
        function_language as LANGUAGE,
        'Triggers' as type,
        function_name as typeName,
        funcname as AWSExtensionDependency,
        sum(cnt) as SCTFunctionReferenceCount
    from trigger_alias2
    where 1 = 1
    group by function_schema,
        function_language,
        function_name,
        funcname
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.schemaName as schema_name,
    src.LANGUAGE as object_language,
    src.type as object_type,
    src.typeName as object_name,
    src.AWSExtensionDependency as aws_extension_dependency,
    src.SCTFunctionReferenceCount as sct_function_reference_count
from src;

-- name: collection-postgres-aws-oracle-exists
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    exists (
        select
        from information_schema.tables
        where table_schema = 'aws_oracle_ext'
            and TABLE_NAME = 'versions'
    ) as sct_oracle_extension_exists;

-- name: collection-postgres-bg-writer-stats
with src as (
    select w.checkpoints_timed,
        w.checkpoints_req as checkpoints_requested,
        w.checkpoint_write_time,
        w.checkpoint_sync_time,
        w.buffers_checkpoint,
        w.buffers_clean,
        w.maxwritten_clean as max_written_clean,
        w.buffers_backend,
        w.buffers_backend_fsync,
        w.buffers_alloc as buffers_allocated,
        w.stats_reset
    from pg_stat_bgwriter w
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.checkpoints_timed,
    src.checkpoints_requested,
    src.checkpoint_write_time,
    src.checkpoint_sync_time,
    src.buffers_checkpoint,
    src.buffers_clean,
    src.max_written_clean,
    src.buffers_backend,
    src.buffers_backend_fsync,
    src.buffers_allocated,
    src.stats_reset
from src;

-- name: collection-postgres-calculated-metrics
with table_summary as (
    select count(distinct c.oid) as total_table_count
    from pg_class c
        join pg_catalog.pg_namespace as ns on (c.relnamespace = ns.oid)
    where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
        and ns.nspname !~ '^pg_toast'
        and c.relkind = ANY (ARRAY ['r', 'p', 't'])
),
foreign_table_summary as (
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
    from pg_catalog.pg_foreign_table ft
        inner join pg_catalog.pg_class c on c.oid = ft.ftrelid
        inner join pg_catalog.pg_foreign_server s on s.oid = ft.ftserver
        inner join pg_catalog.pg_foreign_data_wrapper w on s.srvfdw = w.oid
),
extension_summary as (
    select count(distinct e.extname) total_extension_count,
        count(
            distinct case
                when e.extname = any (
                    array ['btree_gin',
                'btree_gist',
                'chkpass',
                'citext',
                'cube',
                'hstore',
                'isn',
                'ip4r',
                'ltree',
                'lo',
                'postgresql-hll',
                'prefix',
                'postgis',
                'postgis_raster',
                'postgis_sfcgal',
                'postgis_tiger_geocoder',
                'postgis_topology',
                'address_standardizer',
                'address_standardizer_data_us',
                'plpgsql',
                'plv8',
                'amcheck',
                'auto_explain',
                'dblink',
                'decoderbufs',
                'dict_int',
                'earthdistance',
                'fuzzystrmatch',
                'intagg',
                'intarray',
                'oracle_fdw',
                'orafce',
                'pageinspect',
                'pgAudit',
                'pg_bigm',
                'pg_buffercache',
                'pg_cron',
                'pgcrypto',
                'pglogical',
                'pgfincore',
                'pg_freespacemap',
                'pg_hint_plan',
                'pgoutput',
                'pg_partman',
                'pg_prewarm',
                'pg_proctab',
                'pg_repack',
                'pgrowlocks',
                'pgstattuple',
                'pg_similarity',
                'pg_stat_statements',
                'pgtap',
                'pg_trgm',
                'pgtt',
                'pgvector',
                'pg_visibility',
                'pg_wait_sampling',
                'plproxy',
                'postgres_fdw',
                'postgresql_anonymizer',
                'rdkit',
                'refint',
                'sslinfo',
                'tablefunc',
                'tsm_system_rows',
                'tsm_system_time',
                'unaccent',
                'uuid-ossp']
                ) then e.extname
                else null
            end
        ) as supported_extension_count,
        count(
            distinct case
                when e.extname != all (
                    array ['btree_gin',
                'btree_gist',
                'chkpass',
                'citext',
                'cube',
                'hstore',
                'isn',
                'ip4r',
                'ltree',
                'lo',
                'postgresql-hll',
                'prefix',
                'postgis',
                'postgis_raster',
                'postgis_sfcgal',
                'postgis_tiger_geocoder',
                'postgis_topology',
                'address_standardizer',
                'address_standardizer_data_us',
                'plpgsql',
                'plv8',
                'amcheck',
                'auto_explain',
                'dblink',
                'decoderbufs',
                'dict_int',
                'earthdistance',
                'fuzzystrmatch',
                'intagg',
                'intarray',
                'oracle_fdw',
                'orafce',
                'pageinspect',
                'pgAudit',
                'pg_bigm',
                'pg_buffercache',
                'pg_cron',
                'pgcrypto',
                'pglogical',
                'pgfincore',
                'pg_freespacemap',
                'pg_hint_plan',
                'pgoutput',
                'pg_partman',
                'pg_prewarm',
                'pg_proctab',
                'pg_repack',
                'pgrowlocks',
                'pgstattuple',
                'pg_similarity',
                'pg_stat_statements',
                'pgtap',
                'pg_trgm',
                'pgtt',
                'pgvector',
                'pg_visibility',
                'pg_wait_sampling',
                'plproxy',
                'postgres_fdw',
                'postgresql_anonymizer',
                'rdkit',
                'refint',
                'sslinfo',
                'tablefunc',
                'tsm_system_rows',
                'tsm_system_time',
                'unaccent',
                'uuid-ossp']
                ) then e.extname
                else null
            end
        ) as unsupported_extension_count
    from pg_extension e
),
calculated_metrics as (
    select 'VERSION' as metric_name,
        current_setting('server_version_num') as metric_value
    union
    select 'UNSUPPORTED_EXTENSION_COUNT' as metric_name,
        cast(es.unsupported_extension_count as varchar) as metric_value
    from extension_summary es
    union
    select 'SUPPORTED_EXTENSION_COUNT' as metric_name,
        cast(es.supported_extension_count as varchar) as metric_value
    from extension_summary es
    union all
    select 'EXTENSION_COUNT' as metric_name,
        cast(es.total_extension_count as varchar) as metric_value
    from extension_summary es
    union all
    select 'FOREIGN_TABLE_COUNT' as metric_name,
        cast(fts.total_foreign_table_count as varchar) as metric_value
    from foreign_table_summary fts
    union all
    select 'UNSUPPORTED_FOREIGN_TABLE_COUNT' as metric_name,
        cast(fts.unsupported_foreign_table_count as varchar) as metric_value
    from foreign_table_summary fts
    union all
    select 'SUPPORTED_FOREIGN_TABLE_COUNT' as metric_name,
        cast(fts.supported_foreign_table_count as varchar) as metric_value
    from foreign_table_summary fts
    union all
    select 'TABLE_COUNT' as metric_name,
        cast(ts.total_table_count as varchar) as metric_value
    from table_summary ts
),
src as (
    select 'CALCULATED_METRIC' as metric_category,
        metric_name,
        metric_value
    from calculated_metrics
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.metric_category as metric_category,
    src.metric_name as metric_name,
    src.metric_value as metric_value
from src;

-- name: collection-postgres-data-types
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
                ARRAY ['r', 'p', 'S', 'v', 'f', 'm', 'c', 'I', 't']
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
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.table_schema,
    src.table_type,
    src.table_name,
    src.data_type,
    src.data_type_count
from src;

-- name: collection-postgres-extensions
with src as (
    select e.oid as extension_id,
        e.extname as extension_name,
        a.rolname as extension_owner,
        n.nspname as extension_schema,
        e.extrelocatable as is_relocatable,
        e.extversion as extension_version
    from pg_extension e
        join pg_roles a on (e.extowner = a.oid)
        join pg_namespace n on (e.extnamespace = n.oid)
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.extension_id,
    src.extension_name,
    src.extension_owner,
    src.extension_schema,
    src.is_relocatable,
    src.extension_version
from src;

-- name: collection-postgres-index-details
with src as (
    select i.indexrelid as object_id,
        sut.relname as table_name,
        sut.schemaname as table_owner,
        ipc.relname as index_name,
        psui.schemaname as index_owner,
        i.indrelid as table_object_id,
        i.indnatts as indexed_column_count,
        i.indnkeyatts as indexed_keyed_column_count,
        i.indisunique as is_unique,
        i.indisprimary as is_primary,
        i.indisexclusion as is_exclusion,
        i.indimmediate as is_immediate,
        i.indisclustered as is_clustered,
        i.indisvalid as is_valid,
        i.indcheckxmin as is_check_xmin,
        i.indisready as is_ready,
        i.indislive as is_live,
        i.indisreplident as is_replica_identity,
        psui.idx_blks_read as index_block_read,
        psui.idx_blks_hit as index_blocks_hit,
        p.idx_scan as index_scan,
        p.idx_tup_read as index_tuples_read,
        p.idx_tup_fetch as index_tuples_fetched
    from pg_index i
        join pg_stat_user_tables sut on (i.indrelid = sut.relid)
        join pg_class ipc on (i.indexrelid = ipc.oid)
        left join pg_catalog.pg_statio_user_indexes psui on (i.indexrelid = psui.indexrelid)
        left join pg_catalog.pg_stat_user_indexes p on (i.indexrelid = p.indexrelid)
    where psui.indexrelid is not null
        or p.indexrelid is not null
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.object_id,
    replace(src.table_name, chr(34), chr(30)) as table_name,
    replace(src.table_owner, chr(34), chr(30)) as table_owner,
    replace(src.index_name, chr(34), chr(30)) as index_name,
    replace(src.index_owner, chr(34), chr(30)) as index_owner,
    src.table_object_id,
    src.indexed_column_count,
    src.indexed_keyed_column_count,
    src.is_unique,
    src.is_primary,
    src.is_exclusion,
    src.is_immediate,
    src.is_clustered,
    src.is_valid,
    src.is_check_xmin,
    src.is_ready,
    src.is_live,
    src.is_replica_identity,
    src.index_block_read,
    src.index_blocks_hit,
    src.index_scan,
    src.index_tuples_read,
    src.index_tuples_fetched
from src;

-- name: collection-postgres-replication-stats
with src as (
    select r.pid,
        r.usesysid,
        r.usename,
        r.application_name,
        r.client_addr,
        r.client_hostname,
        r.client_port,
        r.backend_start,
        r.backend_xmin,
        r.state,
        r.sent_lsn,
        r.write_lsn,
        r.flush_lsn,
        r.replay_lsn,
        r.write_lag,
        r.flush_lag,
        r.replay_lag,
        r.sync_priority,
        r.sync_state,
        r.reply_time
    from pg_stat_replication r
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.pid,
    src.usesysid,
    src.usename,
    src.application_name,
    src.client_addr,
    src.client_hostname,
    src.client_port,
    src.backend_start,
    src.backend_xmin,
    src.state,
    src.sent_lsn,
    src.write_lsn,
    src.flush_lsn,
    src.replay_lsn,
    src.write_lag,
    src.flush_lag,
    src.replay_lag,
    src.sync_priority,
    src.sync_state,
    src.reply_time
from src;

-- name: collection-postgres-schema-details
with all_schemas as (
    select n.oid as object_id,
        n.nspname as object_schema,
        pg_get_userbyid(n.nspowner) as schema_owner,
        case
            when n.nspname !~ '^pg_'
            and (
                n.nspname <> all (ARRAY ['pg_catalog' , 'information_schema'])
            ) then false
            else true
        end as system_object
    from pg_namespace n
),
all_functions as (
    select n.nspname as object_schema,
        count(distinct p.oid) as function_count
    from pg_proc p
        join pg_namespace n on n.oid = p.pronamespace
    group by n.nspname
),
all_views as (
    select n.nspname as object_schema,
        count(distinct c.oid) as view_count
    from pg_class c
        join pg_namespace n on n.oid = c.relnamespace
    where c.relkind = ANY (ARRAY ['v' , 'm' ])
    group by n.nspname
),
src as (
    select all_schemas.object_schema,
        all_schemas.schema_owner,
        all_schemas.system_object,
        COALESCE(count(all_tables.*), 0) as table_count,
        COALESCE(all_views.view_count, 0) as view_count,
        COALESCE(all_functions.function_count, 0) as function_count,
        sum(pg_table_size(all_tables.oid)) as table_data_size_bytes,
        sum(pg_total_relation_size(all_tables.oid)) as total_table_size_bytes
    from all_schemas
        left join pg_class all_tables on all_schemas.object_id = all_tables.relnamespace
        and (all_tables.relkind = ANY (ARRAY ['r', 'p']))
        left join all_functions on all_functions.object_schema = all_schemas.object_schema
        left join all_views on all_views.object_schema = all_schemas.object_schema
    group by all_schemas.object_schema,
        all_schemas.schema_owner,
        all_schemas.system_object,
        all_views.view_count,
        all_functions.function_count
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.object_schema,
    src.schema_owner,
    src.system_object,
    src.table_count,
    src.view_count,
    src.function_count,
    COALESCE(src.table_data_size_bytes, 0) as table_data_size_bytes,
    COALESCE(src.total_table_size_bytes, 0) as total_table_size_bytes,
    current_database() as database_name
from src;

-- name: collection-postgres-schema-objects
with all_tables as (
    select distinct c.oid as object_id,
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
        pg_get_userbyid(c.relowner) as object_owner
    from pg_class c
        join pg_catalog.pg_namespace as ns on (c.relnamespace = ns.oid)
    where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
        and ns.nspname !~ '^pg_toast'
        and c.relkind = ANY (ARRAY ['r', 'p', 'S', 'f', 'c','t'])
),
all_views as (
    select distinct c.oid as object_id,
        'VIEW' as object_category,
        case
            when c.relkind = 'v' then 'VIEW'
            when c.relkind = 'm' then 'MATERIALIZED_VIEW'
            else 'UNCATEGORIZED_VIEW'
        end as object_type,
        ns.nspname as object_schema,
        c.relname as object_name,
        pg_get_userbyid(c.relowner) as object_owner
    from pg_class c
        join pg_catalog.pg_namespace as ns on (c.relnamespace = ns.oid)
    where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
        and ns.nspname !~ '^pg_toast'
        and c.relkind = ANY (ARRAY [ 'v', 'm'])
),
all_indexes as (
    select distinct i.indexrelid as object_id,
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
        sut.relname as table_name,
        sut.schemaname as object_schema,
        c.relname as object_name,
        pg_get_userbyid(c.relowner) as object_owner
    from pg_index i
        join pg_stat_user_tables sut on (i.indrelid = sut.relid)
        join pg_class c on (i.indexrelid = c.oid)
),
all_constraints as (
    select distinct con.oid as object_id,
        'CONSTRAINT' as object_category,
        case
            when con.contype = 'c' then 'CHECK_CONSTRAINT'
            when con.contype = 'f' then 'FOREIGN_KEY_CONSTRAINT'
            when con.contype = 'p' then 'PRIMARY_KEY_CONSTRAINT'
            when con.contype = 'u' then 'UNIQUE_CONSTRAINT'
            when con.contype = 't' then 'CONSTRAINT_TRIGGER'
            when con.contype = 'x' then 'EXCLUSION_CONSTRAINT'
            else 'UNCATEGORIZED_CONSTRAINT'
        end as object_type,
        ns.nspname as object_schema,
        con.conname as object_name,
        pg_get_userbyid(c.relowner) as object_owner
    from pg_constraint con
        join pg_class as c on con.conrelid = c.oid
        join pg_catalog.pg_namespace as ns on (con.connamespace = ns.oid)
    where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
        and ns.nspname !~ '^pg_toast'
),
all_triggers as (
    select distinct t.tgrelid as object_id,
        'TRIGGER' as object_category,
        case
            t.tgtype::integer & 66
            when 2 then 'BEFORE'
            when 64 then 'INSTEAD_OF'
            else 'AFTER'
        end || '_' || case
            t.tgtype::integer & cast(28 as int2)
            when 16 then 'UPDATE'
            when 8 then 'DELETE'
            when 4 then 'INSERT'
            when 20 then 'INSERT_UPDATE'
            when 28 then 'INSERT_UPDATE_DELETE'
            when 24 then 'UPDATE_DELETE'
            when 12 then 'INSERT_DELETE'
        end || '_' || 'TRIGGER' as object_type,
        ns.nspname as object_schema,
        t.tgname as object_name,
        pg_get_userbyid(c.relowner) as object_owner
    from pg_trigger t
        join pg_class c on t.tgrelid = c.oid
        join pg_namespace ns on ns.oid = c.relnamespace
        /* exclude triggers generated from constraints */
    where t.tgrelid not in (
            select conrelid
            from pg_constraint
        )
),
all_procedures as (
    select distinct p.oid as object_id,
        'SOURCE_CODE' as object_category,
        ns.nspname as object_schema,
        case
            when p.prokind = 'f' then 'FUNCTION'
            when p.prokind = 'p' then 'PROCEDURE'
            when p.prokind = 'a' then 'AGGREGATE_FUNCTION'
            when p.prokind = 'w' then 'WINDOW_FUNCTION'
            else 'UNCATEGORIZED_PROCEDURE'
        end as object_type,
        p.proname as object_name,
        pg_get_userbyid(p.proowner) as object_owner
    from pg_proc p
        left join pg_namespace ns on ns.oid = p.pronamespace
    where ns.nspname <> all (array ['pg_catalog', 'information_schema'])
        and ns.nspname !~ '^pg_toast'
),
src as (
    select a.object_owner,
        a.object_category,
        a.object_type,
        a.object_schema,
        a.object_name,
        a.object_id
    from all_tables a
    union all
    select a.object_owner,
        a.object_category,
        a.object_type,
        a.object_schema,
        a.object_name,
        a.object_id
    from all_views a
    union all
    select a.object_owner,
        a.object_category,
        a.object_type,
        a.object_schema,
        a.object_name,
        a.object_id
    from all_indexes a
    union all
    select a.object_owner,
        a.object_category,
        a.object_type,
        a.object_schema,
        a.object_name,
        a.object_id
    from all_procedures a
    union all
    select a.object_owner,
        a.object_category,
        a.object_type,
        a.object_schema,
        a.object_name,
        a.object_id
    from all_constraints a
    union all
    select a.object_owner,
        a.object_category,
        a.object_type,
        a.object_schema,
        a.object_name,
        a.object_id
    from all_triggers a
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.object_owner,
    src.object_category,
    src.object_type,
    src.object_schema,
    src.object_name,
    src.object_id,
    current_database() as database_name
from src;

-- name: collection-postgres-settings
with src as (
    select s.category as setting_category,
        s.name as setting_name,
        s.setting as setting_value,
        s.unit as setting_unit,
        s.context as context,
        s.vartype as variable_type,
        s.source as setting_source,
        s.min_val as min_value,
        s.max_val as max_value,
        s.enumvals as enum_values,
        s.boot_val as boot_value,
        s.reset_val as reset_value,
        s.sourcefile as source_file,
        s.pending_restart as pending_restart,
        case
            when s.source not in ('override', 'default') then 1
            else 0
        end as is_default
    from pg_settings s
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    replace(src.setting_category, chr(34), chr(39)) as setting_category,
    replace(src.setting_name, chr(34), chr(39)) as setting_name,
    replace(src.setting_value, chr(34), chr(39)) as setting_value,
    src.setting_unit,
    src.context,
    src.variable_type,
    src.setting_source,
    src.min_value,
    src.max_value,
    replace(src.enum_values::text, chr(34), chr(39)) as enum_values,
    replace(src.boot_value::text, chr(34), chr(39)) as boot_value,
    replace(src.reset_value::text, chr(34), chr(39)) as reset_value,
    src.source_file,
    src.pending_restart,
    src.is_default
from src;

-- name: collection-postgres-source-details
with src as (
    select p.oid as object_id,
        n.nspname as schema_name,
        case
            when p.prokind = 'f' then 'FUNCTION'
            when p.prokind = 'p' then 'PROCEDURE'
            when p.prokind = 'a' then 'AGGREGATE_FUNCTION'
            when p.prokind = 'w' then 'WINDOW_FUNCTION'
            else 'UNCATEGORIZED_PROCEDURE'
        end as object_type,
        p.proname as object_name,
        pg_get_function_result(p.oid) as result_data_types,
        pg_get_function_arguments(p.oid) as argument_data_types,
        pg_get_userbyid(p.proowner) as object_owner,
        length(p.prosrc) as number_of_chars,
        (LENGTH(p.prosrc) + 1) - LENGTH(replace(p.prosrc, E'\n', '')) as number_of_lines,
        case
            when p.prosecdef then 'definer'
            else 'invoker'
        end as object_security,
        array_to_string(p.proacl, '') as access_privileges,
        l.lanname as procedure_language,
        case
            when n.nspname <> all (ARRAY ['pg_catalog', 'information_schema']) then false
            else true
        end as system_object
    from pg_proc p
        left join pg_namespace n on n.oid = p.pronamespace
        left join pg_language l on l.oid = p.prolang
)
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    src.object_id,
    replace (src.schema_name, chr(34), chr(39)) as schema_name,
    src.object_type,
    replace (src.object_name, chr(34), chr(39)) as object_name,
    replace (src.result_data_types, chr(34), chr(39)) as result_data_types,
    replace (src.argument_data_types, chr(34), chr(39)) as argument_data_types,
    replace (src.object_owner, chr(34), chr(39)) as object_owner,
    src.number_of_chars,
    src.number_of_lines,
    src.object_security,
    src.access_privileges,
    src.procedure_language,
    src.system_object
from src;
