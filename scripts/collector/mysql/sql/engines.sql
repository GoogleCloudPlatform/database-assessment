with src as (
    select i.ENGINE as engine_name,
        i.SUPPORT as engine_support,
        i.TRANSACTIONS as engine_transactions,
        i.xa as engine_xa,
        i.SAVEPOINTS as engine_savepoints,
        i.COMMENT as engine_comment
    from information_schema.ENGINES i
)
select concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_PKEY_ID,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    src.engine_name,
    src.engine_support,
    src.engine_transactions,
    src.engine_xa,
    src.engine_savepoints,
    src.engine_comment
from src;
