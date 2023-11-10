with src as (
    select i.CONSTRAINT_CATALOG as object_catalog,
        i.CONSTRAINT_SCHEMA as object_schema,
        'CONSTRAINT' as object_category,
        concat(i.CONSTRAINT_TYPE, ' CONSTRAINT') as object_type,
        i.TABLE_SCHEMA as object_owner_schema,
        i.TABLE_NAME as object_owner,
        i.CONSTRAINT_NAME as object_name
    from information_schema.TABLE_CONSTRAINTS i
    WHERE i.CONSTRAINT_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TRIGGER_CATALOG as object_catalog,
        i.TRIGGER_SCHEMA as object_schema,
        'TRIGGER' as object_category,
        concat(
            i.ACTION_TIMING,
            ' ',
            i.EVENT_MANIPULATION,
            ' TRIGGER'
        ) as object_type,
        i.TRIGGER_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.TRIGGER_NAME as object_name
    from information_schema.TRIGGERS i
    WHERE i.TRIGGER_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TABLE_CATALOG as object_catalog,
        i.TABLE_SCHEMA as object_schema,
        'VIEW' as object_category,
        i.TABLE_TYPE as object_type,
        null as object_schema_schema,
        null as object_owner,
        i.TABLE_NAME as object_name
    from information_schema.TABLES i
    where i.table_type = 'VIEW'
        and i.TABLE_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.TABLE_CATALOG as object_catalog,
        i.TABLE_SCHEMA as object_schema,
        'TABLE' as object_category,
        IF(
            pt.PARTITION_METHOD is null,
            'TABLE',
            if(
                pt.SUBPARTITION_METHOD is not null,
                concat(
                    'TABLE-COMPOSITE_PARTITIONED-',
                    pt.PARTITION_METHOD,
                    '-',
                    pt.SUBPARTITION_METHOD
                ),
                concat('TABLE-PARTITIONED-', pt.PARTITION_METHOD)
            )
        ) as object_type,
        null as object_schema_schema,
        null as object_owner,
        i.TABLE_NAME as object_name
    from information_schema.TABLES i
        left join (
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
        ) pt on (
            i.TABLE_NAME = pt.TABLE_NAME
            and i.TABLE_SCHEMA = pt.TABLE_SCHEMA
        )
    where i.table_type != 'VIEW'
        and i.TABLE_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.ROUTINE_CATALOG as object_catalog,
        i.ROUTINE_SCHEMA as object_schema,
        'PROCEDURE' as object_category,
        i.ROUTINE_TYPE as object_type,
        i.ROUTINE_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.ROUTINE_NAME as object_name
    FROM information_schema.ROUTINES i
    WHERE i.ROUTINE_TYPE = 'PROCEDURE'
        AND i.ROUTINE_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.ROUTINE_CATALOG as object_catalog,
        i.ROUTINE_SCHEMA as object_schema,
        'FUNCTION' as object_category,
        i.ROUTINE_TYPE as object_type,
        i.ROUTINE_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.ROUTINE_NAME as object_name
    FROM information_schema.ROUTINES i
    WHERE i.ROUTINE_TYPE = 'FUNCTION'
        AND i.ROUTINE_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    union
    select i.EVENT_CATALOG as object_catalog,
        i.EVENT_SCHEMA as object_schema,
        'EVENT' as object_category,
        i.EVENT_TYPE as object_type,
        i.EVENT_SCHEMA as object_owner_schema,
        i.definer as object_owner,
        i.EVENT_NAME as object_name
    FROM information_schema.EVENTS i
    WHERE i.EVENT_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    UNION
    select i.TABLE_CATALOG as object_catalog,
        i.TABLE_SCHEMA as object_schema,
        'INDEX' as object_category,
        case
            when i.INDEX_TYPE = 'BTREE' then 'INDEX'
            when i.INDEX_TYPE = 'HASH' then 'INDEX-HASH'
            when i.INDEX_TYPE = 'FULLTEXT' then 'INDEX-FULLTEXT'
            when i.INDEX_TYPE = 'SPATIAL' then 'INDEX-SPATIAL'
            else 'INDEX-UNCATEGORIZED'
        end as object_type,
        i.TABLE_SCHEMA as object_owner_schema,
        i.TABLE_NAME as object_owner,
        i.INDEX_NAME as object_name
    from information_schema.STATISTICS i
    where i.INDEX_NAME != 'PRIMARY'
        and i.TABLE_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
)
select concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    src.object_catalog,
    src.object_schema,
    src.object_category,
    src.object_type,
    src.object_owner_schema,
    src.object_owner,
    src.object_name
from src;
