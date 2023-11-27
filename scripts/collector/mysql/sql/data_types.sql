with src as (
    select i.table_catalog as table_catalog,
        i.TABLE_SCHEMA as table_schema,
        i.TABLE_NAME as table_name,
        i.DATA_TYPE as data_type,
        count(1) as data_type_count
    from information_schema.columns i
    where i.TABLE_SCHEMA not in (
            'mysql',
            'information_schema',
            'performance_schema',
            'sys'
        )
    group by i.table_catalog,
        i.TABLE_SCHEMA,
        i.TABLE_NAME,
        i.DATA_TYPE
)
select concat(char(39), @PKEY, char(39)) as pkey,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as dma_source_id,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as dma_manual_id,
    concat(char(39), src.table_catalog, char(39)) as table_catalog,
    concat(char(39), src.table_schema, char(39)) as table_schema,
    concat(char(39), src.table_name, char(39)) as table_name,
    concat(char(39), src.data_type, char(39)) as data_type,
    concat(char(39), src.data_type_count, char(39)) as data_type_count
from src;
