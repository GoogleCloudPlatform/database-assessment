SELECT concat(char(39), @DMA_MANUAL_ID, char(39)) as PKEY,
    concat(char(39), @DMA_SOURCE_ID, char(39)) as DMA_SOURCE_ID,
    concat(char(39), @DMA_MANUAL_ID, char(39)) as DMA_MANUAL_ID,
    @@log_bin,
    @@log_slave_updates
