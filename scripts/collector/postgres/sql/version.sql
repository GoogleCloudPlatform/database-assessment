select chr(39) || :DMA_SOURCE_ID || chr(39) as pkey,
    chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
    chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
    version() as database_version
