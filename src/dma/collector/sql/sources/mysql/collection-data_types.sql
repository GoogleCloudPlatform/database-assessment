-- name: collection-mysql-data-types
select @PKEY as pkey,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id,
    src.table_catalog as table_catalog,
    src.table_schema as table_schema,
    src.table_name as table_name,
    src.data_type as data_type,
    src.data_type_count as data_type_count
from (
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
    ) src;
