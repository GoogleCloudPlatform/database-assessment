\ o output / opdb__aws_oracle_exists_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39) as pkey,
  chr(39) || :DMA_SOURCE_ID || chr(39) AS dma_source_id,
  chr(39) || :DMA_MANUAL_ID || chr(39) AS dma_manual_id,
  EXISTS (
    SELECT
    FROM information_schema.tables
    WHERE table_schema = 'aws_oracle_ext'
      AND TABLE_NAME = 'versions'
  ) AS sct_oracle_extension_exists
