SELECT concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    id as process_id,
    HOST as process_host,
    db as process_db,
    command as process_command,
    TIME as process_time,
    state as process_state
FROM information_schema.processlist;
