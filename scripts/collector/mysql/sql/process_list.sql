select concat(char(39), @PKEY, char(39)) as pkey,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as dma_source_id,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as dma_manual_id,
    concat(char(39), id, char(39)) as process_id,
    concat(char(39), HOST, char(39)) as process_host,
    concat(char(39), db, char(39)) as process_db,
    concat(char(39), command, char(39)) as process_command,
    concat(char(39), TIME, char(39)) as process_time,
    concat(char(39), state, char(39)) as process_state
from information_schema.processlist;
