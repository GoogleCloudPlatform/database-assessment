-- name: collection-postgres-aws-oracle-exists
select :PKEY as pkey,
    :DMA_SOURCE_ID as dma_source_id,
    :DMA_MANUAL_ID as dma_manual_id,
    exists (
        select
        from information_schema.tables
        where table_schema = 'aws_oracle_ext'
            and TABLE_NAME = 'versions'
    ) as sct_oracle_extension_exists
