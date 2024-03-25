-- name: collection-mysql-engines
select concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), src.engine_name, char(34)) as engine_name,
    concat(char(34), src.engine_support, char(34)) as engine_support,
    concat(char(34), src.engine_transactions, char(34)) as engine_transactions,
    concat(char(34), src.engine_xa, char(34)) as engine_xa,
    concat(char(34), src.engine_savepoints, char(34)) as engine_savepoints,
    concat(char(34), src.engine_comment, char(34)) as engine_comment
from (
        select i.ENGINE as engine_name,
            i.SUPPORT as engine_support,
            i.TRANSACTIONS as engine_transactions,
            i.xa as engine_xa,
            i.SAVEPOINTS as engine_savepoints,
            i.COMMENT as engine_comment
        from information_schema.ENGINES i
    ) src;
