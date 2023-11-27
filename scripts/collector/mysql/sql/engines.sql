with src as (
    select i.ENGINE as engine_name,
        i.SUPPORT as engine_support,
        i.TRANSACTIONS as engine_transactions,
        i.xa as engine_xa,
        i.SAVEPOINTS as engine_savepoints,
        i.COMMENT as engine_comment
    from information_schema.ENGINES i
)
select concat(char(39), @PKEY, char(39)) as pkey,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as dma_source_id,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as dma_manual_id,
    concat(char(39), src.engine_name, char(39)) as engine_name,
    concat(char(39), src.engine_support, char(39)) as engine_support,
    concat(char(39), src.engine_transactions, char(39)) as engine_transactions,
    concat(char(39), src.engine_xa, char(39)) as engine_xa,
    concat(char(39), src.engine_savepoints, char(39)) as engine_savepoints,
    concat(char(39), src.engine_comment, char(39)) as engine_comment
from src;
