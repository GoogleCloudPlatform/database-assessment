select chr(39) || :DMA_SOURCE_ID || chr(39) as pkey,
  chr(39) || :DMA_SOURCE_ID || chr(39) as dma_source_id,
  chr(39) || :DMA_MANUAL_ID || chr(39) as dma_manual_id,
  exists (
    select
    from information_schema.tables
    where table_schema = 'aws_oracle_ext'
      and TABLE_NAME = 'versions'
  ) as sct_oracle_extension_exists
