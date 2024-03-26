-- name: collection-mysql-process-list
select concat(char(34), @PKEY, char(34)) as pkey,
    concat(char(34), @DMA_SOURCE_ID, char(34)) as dma_source_id,
    concat(char(34), @DMA_MANUAL_ID, char(34)) as dma_manual_id,
    concat(char(34), id, char(34)) as process_id,
    concat(char(34), HOST, char(34)) as process_host,
    concat(char(34), db, char(34)) as process_db,
    concat(char(34), command, char(34)) as process_command,
    concat(char(34), TIME, char(34)) as process_time,
    concat(char(34), state, char(34)) as process_state
from information_schema.processlist;
