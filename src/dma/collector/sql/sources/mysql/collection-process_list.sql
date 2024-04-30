-- name: collection-mysql-process-list
select @PKEY as pkey,
    @DMA_SOURCE_ID as dma_source_id,
    @DMA_MANUAL_ID as dma_manual_id,
    id as process_id,
    HOST,
    char(34)
) as process_host,
db,
char(34)
) as process_db,
command,
char(34)
) as process_command,
TIME,
char(34)
) as process_time,
state,
char(34)
) as process_state
from information_schema.processlist;
