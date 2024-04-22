-- name: collection-mysql-table-details
select
    /*+ MAX_EXECUTION_TIME(5000) */
    concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), table_schema, char(34)) as table_schema,
    concat(char(34), table_name, char(34)) as table_name,
    concat(char(34), table_engine, char(34)) as table_engine,
    table_rows as table_rows,
    data_length as data_length,
    index_length as index_length,
    concat(char(34), is_compressed, char(34)) as is_compressed,
    concat(char(34), is_partitioned, char(34)) as is_partitioned,
    partition_count as partition_count,
    index_count as index_count,
    fulltext_index_count as fulltext_index_count
from (
        select t.table_schema as table_schema,
            t.table_name as table_name,
            t.table_rows as table_rows,
            t.DATA_LENGTH as DATA_LENGTH,
            t.INDEX_LENGTH as INDEX_LENGTH,
            t.DATA_LENGTH + t.INDEX_LENGTH as total_length,
            t.ROW_FORMAT as row_format,
            t.TABLE_TYPE as table_type,
            t.ENGINE as table_engine,
            if(pks.table_name is not null, 1, 0) as has_primary_key,
            if(t.ROW_FORMAT = 'COMPRESSED', 1, 0) as is_compressed,
            if(pt.PARTITION_METHOD is not null, 1, 0) as is_partitioned,
            COALESCE(pt.PARTITION_COUNT, 0) as partition_count,
            COALESCE(idx.index_count, 0) as index_count,
            COALESCE(idx.fulltext_index_count, 0) as fulltext_index_count,
            COALESCE(idx.spatial_index_count, 0) as spatial_index_count
        from information_schema.TABLES t
            left join (
                select TABLE_SCHEMA,
                    TABLE_NAME,
                    PARTITION_METHOD,
                    SUBPARTITION_METHOD,
                    count(1) as PARTITION_COUNT
                from information_schema.PARTITIONS
                where table_schema not in (
                        'mysql',
                        'information_schema',
                        'performance_schema',
                        'sys'
                    )
                group by TABLE_SCHEMA,
                    TABLE_NAME,
                    PARTITION_METHOD,
                    SUBPARTITION_METHOD
            ) pt on (
                t.table_schema = pt.table_schema
                and t.TABLE_NAME = pt.TABLE_NAME
            )
            left join (
                select table_schema,
                    TABLE_NAME
                from information_schema.statistics
                where table_schema not in (
                        'mysql',
                        'information_schema',
                        'performance_schema',
                        'sys'
                    )
                group by table_schema,
                    TABLE_NAME,
                    index_name
                having SUM(
                        if(
                            non_unique = 0
                            and NULLABLE != 'YES',
                            1,
                            0
                        )
                    ) = count(*)
            ) pks on (
                t.table_schema = pks.table_schema
                and t.TABLE_NAME = pks.TABLE_NAME
            )
            left join (
                select s.table_schema,
                    s.table_name,
                    count(1) as index_count,
                    sum(
                        if(s.INDEX_TYPE = 'FULLTEXT', 1, 0)
                    ) as fulltext_index_count,
                    sum(if(s.INDEX_TYPE = 'SPATIAL', 1, 0)) as spatial_index_count
                from information_schema.STATISTICS s
                where s.table_schema not in (
                        'mysql',
                        'information_schema',
                        'performance_schema',
                        'sys'
                    )
                group by s.table_schema,
                    s.table_name
            ) idx on (
                t.table_schema = idx.table_schema
                and t.TABLE_NAME = idx.TABLE_NAME
            )
        where t.table_schema not in (
                'mysql',
                'information_schema',
                'performance_schema',
                'sys'
            )
    ) user_tables;
