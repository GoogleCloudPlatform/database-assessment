\ o output / opdb__awsoracleexists_ :VTAG.csv
SELECT chr(39) || :PKEY || chr(39),
  chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID,
  chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID,
  EXISTS (
    SELECT
    FROM information_schema.tables
    WHERE table_schema = 'aws_oracle_ext'
      AND TABLE_NAME = 'versions'
  ) AS SCTOracleExtensionExists,
  chr(39) || :DMA_SOURCE_ID || chr(39) AS DMA_SOURCE_ID,
  chr(39) || :DMA_MANUAL_ID || chr(39) AS DMA_MANUAL_ID
