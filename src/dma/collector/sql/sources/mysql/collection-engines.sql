-- name: collection-mysql-engines
select @PKEY as pkey,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id,
    src.engine_name as engine_name,
    src.engine_support,
    char(34)
) as engine_support,
src.engine_transactions,
char(34)
) as engine_transactions,
src.engine_xa,
char(34)
) as engine_xa,
src.engine_savepoints,
char(34)
) as engine_savepoints,
src.engine_comment,
char(34)
) as engine_comment
from (
        select i.ENGINE as engine_name,
            i.SUPPORT as engine_support,
            i.TRANSACTIONS as engine_transactions,
            i.xa as engine_xa,
            i.SAVEPOINTS as engine_savepoints,
            i.COMMENT as engine_comment
        from information_schema.ENGINES i
    ) src;
