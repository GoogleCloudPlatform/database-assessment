with src as (
    select i.table_catalog as table_catalog,
        i.TABLE_SCHEMA as table_schema,
        i.TABLE_NAME as table_name,
        i.DATA_TYPE as data_type,
        count(1) as data_type_count
    from information_schema.COLUMNS i
    WHERE i.TABLE_SCHEMA NOT IN (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    group by i.table_catalog,
        i.TABLE_SCHEMA,
        i.DATA_TYPE
)
select concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    src.table_catalog,
    src.table_schema,
    src.table_name,
    src.data_type,
    src.data_type_count
from src;
