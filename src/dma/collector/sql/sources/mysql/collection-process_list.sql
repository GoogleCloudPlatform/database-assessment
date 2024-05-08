-- name: collection-mysql-process-list
select @PKEY as pkey,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id,
    id as process_id,
    HOST as process_host,
    db as process_db,
    command as process_command,
    TIME as process_time,
    state as process_state
from information_schema.processlist;
