select chr(34) || :PKEY || chr(34) as pkey,
  chr(34) || :DMA_SOURCE_ID || chr(34) as dma_source_id,
  chr(34) || :DMA_MANUAL_ID || chr(34) as dma_manual_id,
  chr(34) || exists (
    select
    from information_schema.tables
    where table_schema = 'aws_oracle_ext'
      and TABLE_NAME = 'versions'
  ) || chr(34) as sct_oracle_extension_exists
