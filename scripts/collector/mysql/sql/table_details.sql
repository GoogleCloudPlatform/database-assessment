with table_partitions as (
    SELECT TABLE_SCHEMA,
        TABLE_NAME,
        PARTITION_METHOD,
        SUBPARTITION_METHOD,
        COUNT(1) AS PARTITION_COUNT
    FROM information_schema.PARTITIONS
    WHERE table_schema NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    GROUP BY TABLE_SCHEMA,
        TABLE_NAME,
        PARTITION_METHOD,
        SUBPARTITION_METHOD
),
tables_with_pks as (
    SELECT table_schema,
        TABLE_NAME
    FROM information_schema.statistics
    WHERE table_schema NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    GROUP BY table_schema,
        TABLE_NAME,
        index_name
    HAVING SUM(
            IF(
                non_unique = 0
                AND NULLABLE != 'YES',
                1,
                0
            )
        ) = COUNT(*)
),
table_indexes as (
    SELECT S.table_schema,
        S.table_name,
        count(1) as index_count,
        sum(
            IF(s.INDEX_TYPE = 'FULLTEXT', 1, 0)
        ) as fulltext_index_count,
        sum(IF(s.INDEX_TYPE = 'SPATIAL', 1, 0)) as spatial_index_count
    FROM information_schema.STATISTICS S
    where S.table_schema NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    group by s.table_schema,
        s.table_name
),
user_tables as (
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
        IF(t.ROW_FORMAT = 'COMPRESSED', 1, 0) as is_compressed,
        IF(pt.PARTITION_METHOD is not null, 1, 0) as is_partitioned,
        COALESCE(pt.PARTITION_COUNT, 0) as partition_count,
        COALESCE(idx.index_count, 0) as index_count,
        COALESCE(idx.fulltext_index_count, 0) as fulltext_index_count,
        COALESCE(idx.spatial_index_count, 0) as spatial_index_count
    FROM information_schema.TABLES t
        left join table_partitions pt on (
            t.table_schema = pt.table_schema
            and t.TABLE_NAME = pt.TABLE_NAME
        )
        left join tables_with_pks pks on (
            t.table_schema = pt.table_schema
            and t.TABLE_NAME = pt.TABLE_NAME
        )
        left join table_indexes idx on (
            t.table_schema = idx.table_schema
            and t.TABLE_NAME = idx.TABLE_NAME
        )
    WHERE t.table_schema NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
)
SELECT
    /*+ MAX_EXECUTION_TIME(5000) */
    concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    table_schema,
    is_compressed,
    table_name,
    table_rows,
    data_length,
    index_length,
    is_compressed,
    is_partitioned,
    partition_count,
    index_count,
    fulltext_index_count
from user_tables;
